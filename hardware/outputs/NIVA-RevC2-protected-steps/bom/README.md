# Costed BOM: NIVA pod (Rev C.1 parts plus the C.2 J2 selection)

The line-by-line data is in `NIVA-pod-BOM-costed.csv`: MPN, supplier part number, URL, price breaks, minimum order quantity, stock and date checked.

**How the prices were gathered (3 November 2026):**
- Every price was taken from a supplier page fetched that day. Prices are in USD as the pages show them.
- LCSC supplied every line except the C.2 J2 line, which is DigiKey.
- Mouser timed out, so it was not used.
- One LCSC price was re-fetched as a spot check: LSM6DSO32TR (C1864162) at USD 6.4961 for 1 and 5.6261 for 10, 248 in stock. It matched.

**Not in this BOM:** the bare PCB, assembly and the stencil all need a quote (PCBWay and others). The cartridge, dock, insole flex, enclosure, screws and strap are separate BOMs.

## Parts cost, per build quantity

| Build | Rev C.1 lines with a price (J2 placeholder unpriced) | Plus J2 = 4 × Mill-Max 0900-0-15-20-76-14-11-0 (C.2) |
|---|---|---|
| 1 board | USD 28.71 | USD 31.79 |
| 10 boards | USD 159.95 (USD 16.00 per board) | USD 186.23 |
| 100 boards | USD 1,215.35 (USD 12.15 per board) | USD 1,438.71 |

Totals are sums of the CSV's extended-cost columns, recomputed from the file.

**Minimum orders:**
- Minimum orders are applied per line. At 1 board, most of the passive cost is forced buys of about 100 pieces.
- R1–R3, R6, R31 and R32 are the same part, so one combined order costs slightly less.

**Partial totals:** these are not quotes. Prices and stock change daily.

## Risks found while pricing

- **ESP32-C3-MINI-1-N4:** DigiKey lists it as "Not For New Designs". LCSC shows it as a normal part. Check the successor before a larger order.
- **MCP3208-CI/SL:** LCSC had 97 in stock, which does not cover 100 boards. DigiKey had 8,083, at USD 2.78 for 1 and 2.11 at 100.
- **LSM6DSO32TR:** none at DigiKey (restock date shown as 28 December 2026). LCSC's 248 was the only stock found.
- **C6:** the proposed 4.7 µF part is rated 16 V, which exceeds the 10 V needed.
- **SW1:** LCSC stocks only the KMR221GLFS variant, so that is the one priced.
- **J2 (C.2):** the DigiKey breaks came from the research pass and were not re-fetched. 400 pieces for 100 boards are priced at the 100-piece break; larger breaks were not checked.
