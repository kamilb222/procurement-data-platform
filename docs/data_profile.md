# Data Profile — purchase_orders.csv

- Generated: 2026-07-04 22:25 UTC
- Source file: `data/raw/purchase_orders.csv`
- Logical rows parsed: 344,504
- Raw physical lines in file: 914,006  (differs from row count — embedded newlines detected in: `Item Name`, `Item Description`, `Classification Codes`, `Location`)
- Columns: 32

## Summary

_Min/Max are lexicographic comparisons of the raw strings, not chronological or numeric ordering — e.g. a "min" date sorting after a "max" date just reflects string sort order._

| Column | Null % | Distinct | Min | Max |
|---|---|---|---|---|
| Creation Date | 0.0% | 1,015 | 1/1/2015 | 9/9/2014 |
| Purchase Date | 5.1% | 2,266 | 1/1/2007 | 9/9/2014 |
| Fiscal Year | 0.0% | 3 | 2012-2013 | 2014-2015 |
| LPA Number | 73.6% | 1,418 | 02702 - Phase I | STPD-SW-1311-01 |
| Purchase Order Number | 0.0% | 197,000 | #14IT-0088 | y0002594 |
| Requisition Number | 95.8% | 5,996 | 006-0001-2 | trdoi00017 |
| Acquisition Type | 0.0% | 5 | IT Goods | NON-IT Services |
| Sub-Acquisition Type | 80.2% | 25 | Agreements with other governmental entities and public univ… | UC, CSU, Community Colleges, and foundations / auxiliaries |
| Acquisition Method | 0.0% | 20 | CMAS | WSCA/Coop |
| Sub-Acquisition Method | 91.0% | 16 | A single firm services a geographic region | Transportation Management Unit (TMU) |
| Department Name | 0.0% | 111 | Administrative Law, Office of | Water Resources, Department of |
| Supplier Code | 0.0% | 25,235 | 0 | 9983 |
| Supplier Name | 0.0% | 24,728 | 1 +Fingerprints & Notary Services | zyncor consulting inc |
| Supplier Qualifications | 58.9% | 278 | CA-DVBE | WOSB |
| Supplier Zip Code | 20.3% | 3,993 | 01545-4197 | n6b1y8 |
| CalCard | 0.0% | 2 | NO | YES |
| Item Name | 0.0% | 179,658 | ! year Repair Service Advantage | Ã¢ÂÂiMac 21.5-inch  /  2.7GHz Quad-core Intel Core i5, Tu… |
| Item Description | 0.1% | 218,696 |  \n \n  \n    \n      \n        MONTHLY SERVICE WILL INCLUD… | âYouth Exploring Sea Level Rise Scienceâ is a collabora… |
| Quantity | 0.0% | 6,080 | 0.0001 | 9999.99 |
| Unit Price | 0.0% | 126,981 | $0.00  | ($997,752.00) |
| Total Price | 0.0% | 149,090 | $0.00  | ($997,752.00) |
| Classification Codes | 0.3% | 45,743 | 10101501 | 95141903 |
| Normalized UNSPSC | 0.3% | 13,405 | 10101501 | 95141903 |
| Commodity Title | 1.0% | 13,072 | #2 Heating fuel oil | pH transmitters |
| Class | 1.0% | 2,347 | 10101500 | 95141900 |
| Class Title | 1.0% | 2,344 | Abrasive wheels | Yarns |
| Family | 1.0% | 409 | 10100000 | 95140000 |
| Family Title | 1.0% | 411 | Accommodation furniture | lized trade construction and maintenance services |
| Segment | 1.0% | 56 | 10000000 | 95000000 |
| Segment Title | 1.0% | 56 | Apparel and Luggage and Personal Care Products | Travel and Food and Lodging and Entertainment Services |
| Location | 20.3% | 3,993 | 01545-4197\n(42.286176, -71.716464) | n6b1y8\n |
| REMOVE AMERISOURCE | 100.0% | 0 | — | — |

## Cross-column checks

### Duplicate rows
- 3,392 rows (0.98%) are exact full-row duplicates.

### Supplier name consistency (same Supplier Code, different Supplier Name)
- 0 of 25,235 supplier codes have more than one distinct Supplier Name.

### Price sanity (Unit Price / Total Price)
- **Unit Price**: 0 unparseable, 7,544 zero, 1,438 negative out of 344,474 non-null values (parsed range: -30,861,228.00 to 7,337,038,064.00)
- **Total Price**: 0 unparseable, 7,511 zero, 1,438 negative out of 344,474 non-null values (parsed range: -30,861,228.00 to 7,337,038,064.00)

## Per-column detail

### Creation Date

- Non-null: 344,504 | Null: 0 (0.0%) | Distinct: 1,015
- Anomalies: none detected

| Value | Count |
|---|---|
| 6/27/2014 | 1,531 |
| 6/2/2014 | 1,409 |
| 6/20/2014 | 1,320 |
| 3/26/2014 | 1,312 |
| 6/26/2015 | 1,253 |
| 11/15/2013 | 1,223 |
| 9/30/2014 | 1,161 |
| 6/7/2013 | 1,135 |
| 8/27/2013 | 1,118 |
| 5/7/2013 | 1,110 |

### Purchase Date

- Non-null: 327,083 | Null: 17,421 (5.1%) | Distinct: 2,266
- Anomalies: none detected

| Value | Count |
|---|---|
| 7/1/2014 | 4,433 |
| 7/1/2013 | 4,417 |
| 7/1/2015 | 2,718 |
| 7/1/2012 | 2,206 |
| 5/1/2013 | 1,219 |
| 5/27/2014 | 1,126 |
| 6/5/2013 | 1,115 |
| 9/25/2013 | 1,070 |
| 3/25/2014 | 1,016 |
| 6/30/2015 | 1,005 |

### Fiscal Year

- Non-null: 344,504 | Null: 0 (0.0%) | Distinct: 3
- Anomalies: none detected

| Value | Count |
|---|---|
| 2013-2014 | 120,158 |
| 2014-2015 | 115,969 |
| 2012-2013 | 108,377 |

### LPA Number

- Non-null: 90,897 | Null: 253,607 (73.6%) | Distinct: 1,418
- Anomalies: none detected

| Value | Count |
|---|---|
| 7-11-51-02 | 9,267 |
| 1-10-75-60A | 3,763 |
| 1-12-65-65-01-E | 3,717 |
| 1-11-70-04O | 3,097 |
| 1-13-70-02A | 2,612 |
| 1-11-70-04Q | 2,481 |
| 1-13-70-01A | 2,098 |
| 1-14-23-20 A - G | 1,620 |
| 1-14-75-60A | 1,479 |
| 1-09-70-01B | 1,358 |

### Purchase Order Number

- Non-null: 344,504 | Null: 0 (0.0%) | Distinct: 197,000
- Anomalies: none detected

| Value | Count |
|---|---|
| 4500211314 | 602 |
| 4500201426 | 579 |
| 4500203794 | 578 |
| 4500204899 | 578 |
| 4500202454 | 564 |
| 4500198630 | 547 |
| 4500215673 | 546 |
| 4500210216 | 546 |
| 4500199706 | 545 |
| 4500212655 | 528 |

### Requisition Number

- Non-null: 14,366 | Null: 330,138 (95.8%) | Distinct: 5,996
- Anomalies: none detected

| Value | Count |
|---|---|
| REQ0008872 | 123 |
| REQ0010655 | 81 |
| REQ0009177 | 65 |
| REQ0010201 | 62 |
| REQ0008985 | 59 |
| REQ0008405 | 55 |
| REQ0010705 | 51 |
| REQ0009336 | 51 |
| REQ0010418 | 49 |
| REQ0010689 | 39 |

### Acquisition Type

- Non-null: 344,504 | Null: 0 (0.0%) | Distinct: 5
- Anomalies: none detected

| Value | Count |
|---|---|
| NON-IT Goods | 213,578 |
| NON-IT Services | 68,369 |
| IT Goods | 50,896 |
| IT Services | 11,514 |
| IT Telecommunications | 147 |

### Sub-Acquisition Type

- Non-null: 68,334 | Null: 276,170 (80.2%) | Distinct: 25
- Anomalies: none detected

| Value | Count |
|---|---|
| Personal Services | 16,104 |
| Services are specifically exempt by statute | 11,852 |
| Emergency Contract | 7,913 |
| Subvention and Local Assistance | 7,048 |
| Public Works | 4,791 |
| Expert Witneses | 3,800 |
| Interagency Agreements | 3,261 |
| Agreements with other governmental entities and public univ… | 2,051 |
| Architectural and Engineering | 1,785 |
| Contracts with Local Governments | 1,561 |

### Acquisition Method

- Non-null: 344,504 | Null: 0 (0.0%) | Distinct: 20
- Anomalies: none detected

| Value | Count |
|---|---|
| Informal Competitive | 82,046 |
| Statewide Contract | 62,041 |
| SB/DVBE Option | 38,500 |
| Services are specifically exempt by statute | 33,040 |
| State Programs | 27,842 |
| Fair and Reasonable | 25,397 |
| WSCA/Coop | 19,478 |
| Formal Competitive | 18,475 |
| Services are specifically exempt by policy | 11,301 |
| Emergency Purchase | 10,186 |

### Sub-Acquisition Method

- Non-null: 30,883 | Null: 313,621 (91.0%) | Distinct: 16
- Anomalies: none detected

| Value | Count |
|---|---|
| Fleet | 14,148 |
| Prison Industry Authority (PIA) | 11,602 |
| Only goods and services that meet needs of the State | 1,798 |
| Office of State Printing (OSP) | 812 |
| Interagency Agreement | 565 |
| Services are specifically exempt by statute | 521 |
| Other | 503 |
| Emergency acquisition for the protection of the public | 334 |
| A single firm services a geographic region | 327 |
| Contract with other government agency | 117 |

### Department Name

- Non-null: 344,504 | Null: 0 (0.0%) | Distinct: 111
- Anomalies: none detected

| Value | Count |
|---|---|
| Corrections and Rehabilitation, Department of | 57,533 |
| Correctional Health Care Services | 31,887 |
| Water Resources, Department of | 28,331 |
| Forestry and Fire Protection, Department of | 23,244 |
| State Hospitals, Department of | 18,912 |
| Transportation, Department of | 17,644 |
| Consumer Affairs, Department of | 15,059 |
| General Services, Department of | 10,813 |
| Highway Patrol, California | 9,515 |
| Pesticide Regulation, Department of | 8,553 |

### Supplier Code

- Non-null: 344,468 | Null: 36 (0.0%) | Distinct: 25,235
- Anomalies: none detected

| Value | Count |
|---|---|
| 1743406 | 13,756 |
| 1001584 | 9,441 |
| 1065902 | 8,508 |
| 1008361 | 6,991 |
| 1087660 | 6,709 |
| 17224 | 5,979 |
| 1755386 | 5,033 |
| 0 | 4,473 |
| 12341 | 3,983 |
| 1752319 | 3,625 |

### Supplier Name

- Non-null: 344,468 | Null: 36 (0.0%) | Distinct: 24,728
- **Anomalies:**
  - 2 value(s) show possible mojibake (double-encoded text, e.g. 'Ã¢ÂÂ'; heuristic — may include false positives on legitimate accented characters)

| Value | Count |
|---|---|
| Voyager Fleet Systems Inc | 13,756 |
| Grainger Industrial Supply | 9,441 |
| Prison Industry Authority | 8,979 |
| 3B INDUSTRIES INC | 6,991 |
| Technology Integration Group | 6,817 |
| Smile Business Products, Inc | 5,979 |
| Western Blue, an NWN Company | 5,045 |
| Unknown | 4,473 |
| TAGG Industries, Inc. | 3,983 |
| McKesson Medical - Surgical Minnesota Su | 3,846 |

### Supplier Qualifications

- Non-null: 141,745 | Null: 202,759 (58.9%) | Distinct: 278
- Anomalies: none detected

| Value | Count |
|---|---|
| CA-MB CA-SB | 53,077 |
| CA-SB | 33,221 |
| CA-MB CA-SB CA-SBE | 7,744 |
| CA-DVBE CA-MB CA-SB | 5,661 |
| CA-SB CA-SBE | 5,630 |
| CA-MB CA-SB SB | 3,781 |
| CA-SB SB | 2,950 |
| CA-DVBE CA-SB CDVBE | 2,236 |
| CA-SB CA-SBE SB | 1,954 |
| CA-DVBE CA-SB CA-SBE CDVBE | 1,829 |

### Supplier Zip Code

- Non-null: 274,424 | Null: 70,080 (20.3%) | Distinct: 3,993
- Anomalies: none detected

| Value | Count |
|---|---|
| 95691 | 11,095 |
| 95814 | 10,921 |
| 95696 | 8,518 |
| 95827 | 7,159 |
| 95841 | 7,008 |
| 73529 | 6,991 |
| 95742 | 5,676 |
| 95811 | 4,779 |
| 93706 | 4,412 |
| 92653 | 4,027 |

### CalCard

- Non-null: 344,504 | Null: 0 (0.0%) | Distinct: 2
- Anomalies: none detected

| Value | Count |
|---|---|
| NO | 339,132 |
| YES | 5,372 |

### Item Name

- Non-null: 344,472 | Null: 32 (0.0%) | Distinct: 179,658
- **Anomalies:**
  - 61 value(s) with leading/trailing whitespace
  - 26 value(s) contain an embedded newline/carriage return
  - 1,078 value(s) show possible mojibake (double-encoded text, e.g. 'Ã¢ÂÂ'; heuristic — may include false positives on legitimate accented characters)

| Value | Count |
|---|---|
| Medical Supplies | 2,911 |
| Contract | 2,092 |
| ew | 1,539 |
| Expert Witness | 1,317 |
| medical vocational training | 1,092 |
| Toner | 1,046 |
| contract | 983 |
| Office Supplies | 959 |
| Dental Supplies | 772 |
| toner | 658 |

### Item Description

- Non-null: 344,303 | Null: 201 (0.1%) | Distinct: 218,696
- **Anomalies:**
  - 161 value(s) with leading/trailing whitespace
  - 40,739 value(s) contain an embedded newline/carriage return
  - 2,286 value(s) show possible mojibake (double-encoded text, e.g. 'Ã¢ÂÂ'; heuristic — may include false positives on legitimate accented characters)

| Value | Count |
|---|---|
| confidential | 1,637 |
| Medical Supplies | 1,386 |
| medical vocational training | 1,084 |
| medical training | 857 |
| vest | 780 |
| Medical Training | 712 |
| x | 707 |
| Software | 691 |
| loan repayment | 683 |
| Toner | 646 |

### Quantity

- Non-null: 344,474 | Null: 30 (0.0%) | Distinct: 6,080
- Anomalies: none detected

| Value | Count |
|---|---|
| 1 | 212,606 |
| 2 | 18,377 |
| 4 | 8,793 |
| 3 | 8,282 |
| 10 | 7,053 |
| 5 | 6,377 |
| 6 | 5,852 |
| 20 | 4,108 |
| 12 | 3,756 |
| 8 | 3,342 |

### Unit Price

- Non-null: 344,474 | Null: 30 (0.0%) | Distinct: 126,981
- **Anomalies:**
  - 343,036 value(s) with leading/trailing whitespace
  - 344,474 value(s) contain `$` or a thousands separator
  - 1,438 value(s) use accounting-style parentheses for negative amounts (e.g. "($7.00)")

| Value | Count |
|---|---|
| $0.00  | 7,544 |
| $1.00  | 3,537 |
| $10,000.00  | 2,199 |
| $50,000.00  | 1,221 |
| $4.00  | 1,139 |
| $15,000.00  | 1,048 |
| $20,000.00  | 941 |
| $25,000.00  | 917 |
| $30,000.00  | 913 |
| $1.75  | 865 |

### Total Price

- Non-null: 344,474 | Null: 30 (0.0%) | Distinct: 149,090
- **Anomalies:**
  - 343,036 value(s) with leading/trailing whitespace
  - 344,474 value(s) contain `$` or a thousands separator
  - 1,438 value(s) use accounting-style parentheses for negative amounts (e.g. "($7.00)")

| Value | Count |
|---|---|
| $0.00  | 7,511 |
| $10,000.00  | 2,282 |
| $50,000.00  | 1,259 |
| $15,000.00  | 1,149 |
| $20,000.00  | 1,003 |
| $30,000.00  | 976 |
| $25,000.00  | 962 |
| $40,000.00  | 692 |
| $5,000.00  | 675 |
| $4,999.00  | 615 |

### Classification Codes

- Non-null: 343,487 | Null: 1,017 (0.3%) | Distinct: 45,743
- **Anomalies:**
  - 58,602 value(s) contain an embedded newline/carriage return

| Value | Count |
|---|---|
| 15101506 | 12,679 |
| 44103103 | 6,905 |
| 86101605 | 4,769 |
| 85101705 | 4,198 |
| 80121903 | 3,622 |
| 81112201 | 3,386 |
| 44101501 | 2,249 |
| 86101802 | 2,216 |
| 56101504 | 2,200 |
| 43211507 | 1,943 |

### Normalized UNSPSC

- Non-null: 343,487 | Null: 1,017 (0.3%) | Distinct: 13,405
- Anomalies: none detected

| Value | Count |
|---|---|
| 15101506 | 12,776 |
| 44103103 | 7,274 |
| 86101605 | 4,783 |
| 85101705 | 4,204 |
| 81112201 | 3,745 |
| 80121903 | 3,625 |
| 43211503 | 2,609 |
| 44101501 | 2,578 |
| 14111507 | 2,455 |
| 56101504 | 2,426 |

### Commodity Title

- Non-null: 341,211 | Null: 3,293 (1.0%) | Distinct: 13,072
- **Anomalies:**
  - 30 value(s) show possible mojibake (double-encoded text, e.g. 'Ã¢ÂÂ'; heuristic — may include false positives on legitimate accented characters)

| Value | Count |
|---|---|
| Gasoline or Petrol | 12,776 |
| Printer or facsimile toner | 7,274 |
| Medical vocational training services | 4,783 |
| Public health administration | 4,204 |
| Maintenance or support fees | 3,745 |
| Expert witness service | 3,625 |
| Notebook computers | 2,609 |
| Photocopiers | 2,578 |
| Printer or copier paper | 2,455 |
| Chairs | 2,426 |

### Class

- Non-null: 341,211 | Null: 3,293 (1.0%) | Distinct: 2,347
- Anomalies: none detected

| Value | Count |
|---|---|
| 15101500 | 14,584 |
| 44103100 | 9,457 |
| 14111500 | 7,189 |
| 81112200 | 7,023 |
| 43211500 | 6,974 |
| 86101600 | 4,951 |
| 85101700 | 4,478 |
| 76122400 | 4,458 |
| 81111800 | 4,121 |
| 56101500 | 3,980 |

### Class Title

- Non-null: 341,211 | Null: 3,293 (1.0%) | Distinct: 2,344
- Anomalies: none detected

| Value | Count |
|---|---|
| Petroleum and distillates | 14,584 |
| Printer and facsimile and photocopier supplies | 9,457 |
| Printing and writing paper | 7,189 |
| Software maintenance and support | 7,023 |
| Computers | 6,974 |
| Scientific vocational training services | 4,951 |
| Health administration services | 4,478 |
| Refuse disposal and treatment fees | 4,458 |
| System and system component administration services | 4,121 |
| Furniture | 3,980 |

### Family

- Non-null: 341,211 | Null: 3,293 (1.0%) | Distinct: 409
- Anomalies: none detected

| Value | Count |
|---|---|
| 44100000 | 16,478 |
| 15100000 | 14,599 |
| 81110000 | 13,942 |
| 43210000 | 13,851 |
| 14110000 | 10,771 |
| 86100000 | 9,785 |
| 44120000 | 9,342 |
| 43230000 | 8,272 |
| 76120000 | 5,433 |
| 56100000 | 5,177 |

### Family Title

- Non-null: 341,211 | Null: 3,293 (1.0%) | Distinct: 411
- Anomalies: none detected

| Value | Count |
|---|---|
| Office machines and their supplies and accessories | 16,478 |
| Fuels | 14,599 |
| Computer services | 13,942 |
| Computer Equipment and Accessories | 13,851 |
| Paper products | 10,771 |
| Vocational training | 9,785 |
| Office supplies | 9,342 |
| Software | 8,272 |
| Refuse disposal and treatment | 5,433 |
| Accommodation furniture | 5,177 |

### Segment

- Non-null: 341,211 | Null: 3,293 (1.0%) | Distinct: 56
- Anomalies: none detected

| Value | Count |
|---|---|
| 43000000 | 32,679 |
| 50000000 | 27,875 |
| 44000000 | 27,744 |
| 81000000 | 17,344 |
| 42000000 | 16,469 |
| 15000000 | 16,029 |
| 14000000 | 11,234 |
| 25000000 | 10,965 |
| 86000000 | 10,643 |
| 46000000 | 10,195 |

### Segment Title

- Non-null: 341,211 | Null: 3,293 (1.0%) | Distinct: 56
- Anomalies: none detected

| Value | Count |
|---|---|
| Information Technology Broadcasting and Telecommunications | 32,679 |
| Food Beverage and Tobacco Products | 27,875 |
| Office Equipment and Accessories and Supplies | 27,744 |
| Engineering and Research and Technology Based Services | 17,344 |
| Medical Equipment and Accessories and Supplies | 16,469 |
| Fuels and Fuel Additives and Lubricants and Anti corrosive … | 16,029 |
| Paper Materials and Products | 11,234 |
| Commercial and Military and Private Vehicles and their Acce… | 10,965 |
| Education and Training Services | 10,643 |
| Defense and Law Enforcement and Security and Safety Equipme… | 10,195 |

### Location

- Non-null: 274,424 | Null: 70,080 (20.3%) | Distinct: 3,993
- **Anomalies:**
  - 3,202 value(s) with leading/trailing whitespace
  - 274,424 value(s) contain an embedded newline/carriage return

| Value | Count |
|---|---|
| 95691\n(38.575311, -121.560401) | 11,095 |
| 95814\n(38.580427, -121.494396) | 10,921 |
| 95696\n(38.43, -122.02) | 8,518 |
| 95827\n(38.563097, -121.328511) | 7,159 |
| 95841\n(38.662263, -121.346136) | 7,008 |
| 73529\n(34.361458, -97.971748) | 6,991 |
| 95742\n(38.585855, -121.217204) | 5,676 |
| 95811\n(38.581053, -121.488564) | 4,779 |
| 93706\n(36.675079, -119.865393) | 4,412 |
| 92653\n(33.595874, -117.702101) | 4,027 |

### REMOVE AMERISOURCE

- Non-null: 0 | Null: 344,504 (100.0%) | Distinct: 0
- Anomalies: none detected
