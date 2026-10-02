# NIVA × SIH 2026 PS 26004: research dossier

Prepared 28 Sep 2026. Every number here was checked against the source listed.

## 1. The problem statement, decoded

**PS 26004:** *AI-Assisted Early Detection System for Osteoarthritis (OA) Risk Markers in North Eastern Region (NER)*.
- **Organisation:** Ministry of Development of North Eastern Region (MDoNER).
- **Category:** Hardware.

| # | PS words | NIVA answer | Status |
|---|---|---|---|
| a1 | Joint movement analysis | Shank IMU (LSM6DSO32, 200 Hz): shank angle and angular velocity in walking and chair-rise | Design |
| a2 | Gait and posture assessment | 5-point insole plus IMU: cadence, stance/swing, CoP path, left–right symmetry, knee-load features | Engine built (web/Flutter); hardware at design stage |
| a3 | Pain and mobility screening inputs | App questionnaire (pain and function) plus a timed chair-rise | Planned app module |
| a4 | Sensor-based assessment | Passive insole plus shin pod, bilateral | Design, KiCad DRC-clean |
| b | AI/ML to find high-risk cases | Explainable features, then referral triage. Rules today; ML only on X-ray-labelled camp data | Rules built; ML planned |
| c | PHCs, rural camps, outreach | Camp kit in a carry case; one health worker runs it | Design |
| d | Preliminary risk and severity indication | Green / amber / red referral triage (not a diagnosis) | Planned |
| e | Digital symptom and screening records | Encrypted on-phone records plus a PDF report | Datasets and CSV export built; report planned |
| f | Multilingual, easy UI | Picture-card workflow plus local languages (Bhashini add-on) | Planned |
| g | Offline, low connectivity | Everything on-device; sync later, only with consent | Built (IndexedDB/Hive) |
| h | Awareness and preventive guidance | Joint-care, activity and footwear guidance cards after each screen | Planned |

## 2. Verified numbers

| Number | Claim | Source |
|---|---|---|
| **62.35 M** | Indians with OA in 2019, up from 23.46 M in 1990 (2.7×) | Singh et al., *Osteoarthritis & Cartilage* 2022 (GBD 2019), abstract via Europe PMC |
| **20.24 %** (95 % CI 11.9–30.1) | Pooled knee-OA prevalence, 16 community studies. Rural 18.64 % | Hazra et al., *Indian J Orthop* 2025 (PMC12615881) |
| **28.7 %** | Knee-OA prevalence, 5-site community study (villages 29.2 %) | Pal et al., *Indian J Orthop* 2016 (PMID 27746495) |
| **79.9 %** | Shortfall of specialists at rural CHCs (4,413 of 21,964 in post, Mar 2023) | MoHFW *Health Dynamics of India 2022-23* (PIB, Sep 2024) |
| **6.46×** | Risk of radiographic progression per 1 % increase in knee adduction moment (KAM) | Miyazaki et al., *Ann Rheum Dis* 2002 (PMC1754164) |
| **r 0.88–0.98** | Insole + ML knee-load prediction in walking. **r 0.50** for sit-to-stand | Snyder et al., *J Biomech* 2025, doi 10.1016/j.jbiomech.2025.112921 |
| **auROC 0.83** | Insole ML separating knee OA from controls, on an independent dataset | Wipperman et al., *eLife* 2024, doi 10.7554/eLife.86132 |
| **56 % specificity** | Shoe-IMU-only classifier, OA vs healthy | Raza et al., *Clin Biomech* 2024, doi 10.1016/j.clinbiomech.2024.106285 |
| **≈ 15 %** | Higher peak KAM in clogs and stability shoes than in flat shoes or flip-flops | Shakoor et al., *Arthritis Care Res* 2010, doi 10.1002/acr.20165 |
| **≤ 9 sensors** | Caution advised on CoP accuracy; only 11+ sensors reached good agreement | Fuchs et al., *Sensors* 2024, doi 10.3390/s24154918 |
| **0.1–10 N vs 445 N** | FSR402 rated range vs FlexiForce A201 (100 lb) | Interlink FSR402 and Tekscan A201 datasheets (engineering brief §1) |
| **€1,495 / pair** | Moticon OpenGo research insoles, plus accessories and software licence | Moticon EUR price list, valid from Jan 2026 |
| **₹1,175–1,199** | FlexiForce A201-100 lb, each (5 per insole ≈ ₹5,900–6,000) | IndiaMART / ExportersIndia listings, 28 Sep 2026 (brief §10) |
| **₹242** | ESP32-C3 SuperMini | Probots listing (brief §10) |
| **≈ 35 mA → ≈ 8.6 h** | Recording current (upper bound) and runtime on a 300 mAh planning cell | Brief §6, from datasheets |

**Do not use:** the "r = 0.96, Snyder 2023" figure. It is unverified.

## 3. The field (other PS 26004 teams on GitHub, 28 Sep 2026)

| Team | Platform | Gap NIVA exploits |
|---|---|---|
| **SAMVEDNA** (Kanis007) | Knee band: acoustic emission, dual IMU, pressure; RF/GBT + SHAP; Flutter offline | No foot-force-based knee-load estimate; pressure only for asymmetry |
| **Ananyark** (12345sud) | ESP32-S3 + MPU6050 + **FSR402** insole, "jumper wires" | FSR402 is rated 0.1–10 N, so it saturates under body weight. No footwear strategy, no quality gate |
| **OA-SATHI** (shrenik111) | Screening tool (details thin) | Likely questionnaire or app-only |

**Typical ideas:** phone-camera pose apps (MediaPipe), X-ray KL-grade CNNs (need an X-ray, which camps lack), questionnaires, knee sleeves.

**NIVA's white space:**
1. It estimates **knee load** (the progression driver), not generic gait.
2. It uses sensors **rated for body weight**.
3. It works in the patient's **own chappal, sandal or shoe**.
4. It is **bilateral and synchronised**.
5. A **recording-quality gate** means no silent bad data.
6. Its **referral triage** is honest about what it can and cannot claim.

## 4. What already exists (reuse in the deck)

- **Software:**
  - ESP32 firmware (FSR + piezo + MPU6050, WebSocket/Serial);
  - React/Vite clinician dashboard, **live at shubham-sahu.me/niva** (simulation mode);
  - Flutter patient app;
  - an explainable biomechanics engine (gait phase, CoP, cadence, stability, anomaly rules).
- **Hardware design (Rev C.1, not fabricated):**
  - 5 KiCad 9 boards with ERC/DRC 0 errors;
  - FreeCAD printable pod and dock;
  - GLB/STEP models and Blender renders;
  - 6 vector blueprint sheets;
  - a verification plan (E1–E7);
  - an engineering brief with the BOM in INR.
- **Also drafted:** a CDSCO classification request (`docs/Niva_CDSCO_Classification_Request.docx`).

## 5. Judge Q&A

| Question | Answer |
|---|---|
| "Is this a diagnosis?" | No. It is referral triage: who should get an X-ray or clinical exam. It is a screening aid, and a CDSCO classification request is drafted. |
| "Can 5 points give knee load?" | Published insoles reach r 0.88–0.98 for walking KAM (Snyder 2025). Ours is unproven until the gait-lab gate (Stage 3). If it fails, we drop the KAM claim and screen on timing and symmetry, which the hardware still measures. |
| "Why not a phone camera?" | A camera cannot see force. Load is what drives progression (Miyazaki 6.46×). Cameras also struggle with the lighting, clothing and space of a camp. |
| "Why not the cheaper FSR402?" | It is rated for 10 N; body weight is hundreds of N. We bench-test both (E1) and pick on data. |
| "Chappals move." | A heel keeper and a toe-post slot hold the insert, and slip is measured per footwear (E4). Footwear is recorded as a covariate. |
| "What is built?" | Firmware, the web dashboard (live), the Flutter app, 5 DRC-clean boards and printable CAD. Nothing has been clinically tested, and we say so. |
