# 05 — Reverse-engineering notes: Canon G2010 over USB

*Ground truth sources: Canon's GPL Linux driver `cnijfilter2` 6.90 (source tree
kept at `cnijfilter2-src/`), string tables of Canon's closed libraries, live
IORegistry/USB telemetry, and CUPS logs from the failing Mac driver.*

## 1. Device identity & USB topology

```
idVendor  0x04A9 (Canon)      idProduct 0x183A      bcdDevice 0x0104 (fw 1.040)
bcdUSB    0x0200 (USB 2.0)    Hi-Speed 480 Mbps     bDeviceClass 0 (per-iface)
serial    "0C7A8F"            1 configuration
Interface @0: vendor-specific (bInterfaceSubClass=0, bInterfaceProtocol=0xFF)
              → proprietary print/status channel (bulk OUT + bulk IN)
Interface @1: subclass 1 / protocol 2 → secondary channel (scanner/MFP side,
              driven by SANE pixma and the ICA stack)
```

IEEE-1284 device ID returned via USB side-channel (`GET_DEVICE_ID`):

```
SERN:0C7A8F;MFG:Canon;CMD:BJRaster3,IVEC;MDL:G2010 series;CLS:PRINTER;
DES:Canon G2010 series;VER:1.040;STA:10;PSE:KLHP82489;CID:CA_BJR520_IJP;
```

- `CMD:BJRaster3,IVEC` — the printer understands **two dialects**: a raster
  mode (BJRaster3) and an XML command mode (**IVEC**).
- `STA:10` — non-zero condition flag; correlates with the driver's
  "ink unknown" gating (see [01-DIAGNOSIS.md](01-DIAGNOSIS.md)).
- Linux driver checks this same field for `"IVEC"` to select protocol
  (`cnijfilter2-src/lgmon3/src/cnijifusb.c`, `CNIF_USB_IsIvec`).

## 2. Driver stacks compared

### macOS (Canon, closed — the one that fails)
```
app → cgtexttopdf/cgpdftoraster (Apple)
    → Raster2CanonIJS  (universal bin; links BJCommand2/BJEssential2/
                        BJStatus2/CIJPrinterUtility; libcups+libcupsimage)
        · builds IVEC commands, encodes page data
        · polls queue state via localhost IPP; reads back-channel on FD 3
    → stdout pipe → /usr/libexec/cups/backend/usb (Apple) → IOKit bulk pipes
```

### Linux (cnijfilter2, mostly open)
```
rastertocanonij (GPL filter)
  └─ sh -c "tocnpwg <opts> | tocanonij <opts>"
       tocnpwg : raster → intermediate CNIJPWG frames (struct CNDATA,
                 magic MAGIC_NUMBER_FOR_CNIJPWG, per-page color mode)
       tocanonij: builds IVEC job via libcnbpcnclapicom2.so (closed blob)
  → cnijbe2 backend (GPL wrapper; forks cnijlgmon3 monitor)
      transport = CNNL_* session API in libcnnet2.so (closed):
      Init/Open/SessionStart/StartPrint/DataWrite/DataRead/EndPrint/SoftReset
```

Mac↔Linux component map:

| Role | macOS | Linux |
|---|---|---|
| Raster→page frames | inside Raster2CanonIJS | `tocnpwg` |
| Command/session layer | BJCommand2 + friends | `tocanonij` + libcnbpcnclapicom2 |
| Status parsing | BJStatus2 | lgmon3 + CLSS_Parse* |
| Transport | Apple usb backend | libcnnet2 / libusb |

## 3. IVEC — the wire protocol

Commands are **XML documents** (namespace
`http://www.canon.com/ns/cmd/2008/07/common/`, extension prefix `vcn:`),
recovered verbatim from `libcnbpcnclapicom2.so` string tables:

```xml
<?xml version="1.0" encoding="utf-8" ?>
<cmd xmlns:ivec="http://www.canon.com/ns/cmd/2008/07/common/"
     xmlns:vcn="http://www.canon.com/ns/cmd/2008/07/canon/">
 <ivec:contents>
  <ivec:operation>StartJob</ivec:operation>
  <ivec:param_set servicetype="print">
   <ivec:jobID>…</ivec:jobID>
   <ivec:bidi>ON</ivec:bidi>
   <vcn:host_environment>…</vcn:host_environment>
  </ivec:param_set>
 </ivec:contents>
</cmd>
```

Operation catalog recovered:

| Operation | Notable parameters |
|---|---|
| `StartJob` | jobID, bidi, jobname/username/computername, `job_description` CDATA, host_environment; variants with `forcepmdetection OFF`, `key_misdetection ON` |
| `EndJob` / `CancelJob` | servicetype + jobID |
| `GetStatus` | servicetype print/maintenance/device (+jobID) |
| `GetCapability` / `GetConfiguration` / `GetJobIDList` | servicetype |
| `SetConfiguration` | settings + `selfPLIagreement`; built from PPD capability XML |
| `SetJobConfiguration` | datetime (maintenance service) |
| `SetPageConfiguration` | `nextpage ON/OFF`, `printpreparation manualfeed` |
| `SendData` | `format RAW` + datasize/datawidth/datalength — the raster payload frame; also JPEG variant |
| `VendorCmd` | `ModeShift`/ijmode, FRomUpMode, HandOverOff |
| `PowerOff` | — |

Response side parsed by `CLSS_ParseStatusResponsePrint/Maintenance`,
`CLSS_ParseCapabilityResponsePrint_*` (HostEnvironment, DateTime, MediaType,
MediaMap, PaperSize, Pixels, NextPage, PrintPreparation, JobQueue…). Observed
status vocabulary includes `busying`, `canceling`, `AttentionRequired`.

Framing on the bulk pipe is handled by the closed `CNNL_*` session layer
(length-prefixed packets); exact byte framing was not needed for our solution
since we reuse Apple's usb backend as transport.

## 4. Job sequence (from `tocanonij/src/main.c`)

```
GetProtocol(deviceID from PPD "CNIJ-DEVCE-INFO")        # prot==2 ⇒ modern
WriteHeader:
    prot==2 : StartJob3(hostEnv ← capability XML) 
              [+ SetJobConfiguration(datetime)]
    else    : OutputSetTime(START1, START2, BJL SetTime, END) + START1
    always  : GetSetConfigurationCommand(settings + capability XML)
WriteData: per CNDATA frame → per-page SetPageConfiguration(nextpage …)
           + SendData(RAW/JPEG, sizes)
WriteTail: EndJob
```

Capability descriptors are embedded in PPDs as encoded comment blocks:

```
*% #CNIJ-IVEC-CAPABILITY>  …base-26-ish alphabet, decoded by
*% #<CNIJ-IVEC-CAPABILITY  CNCL_DecodeFromString (closed lib)
*% #CNIJ-DEVCE-INFO> …
```

Maintenance/utility commands are plain BJL text mapped in per-model plists
(mac: `CIJUtilityCommand.bundle/Resources/*CIJCommandInfo.ucmd`), e.g.
`@CLEANING=1ALL`, deep clean `@CLEANING=2ALL`, alignment `@TESTPRINT=REGI_AUTO1`.

Model parameter database on the Mac: `cnb_4650.tbl` (PPD `*CNIJTableID: 465`,
header `BFCWCanonIJPrinter2005 v1.10`).

## 5. Status semantics (lgmon3 headers)

```
CN_IVEC_STATUS_IDLE=1  PROCESSING=2  STOPPED=3  NOTREADY=4  CANCELING=6
detail: MEDIA_JAM=2  DOOR_OPEN=3  MEDIA_EMPTY=4  BUSYING=6
CLSS_OK_AND_IDLE=11
```

The observed failure signature — endless `GetStatus` polling with the printer
answering but never reaching a state the driver accepts — matches a status gate
rather than any transport fault.

## 6. What we deliberately did NOT do

- Decode the capability blobs byte-for-byte (decoder lives in a closed lib;
  not required once the working path bypasses it).
- Capture live USB traffic (no usbmon on macOS; would need root/SIP changes).
- Touch the scanner protocol — SANE pixma already implements it correctly.
