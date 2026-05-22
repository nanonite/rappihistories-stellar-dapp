import { MedRecord } from "@/types";

const CONTRACT_ID =
  process.env.NEXT_PUBLIC_MEDICAL_CONTRACT_ID ||
  "CDLZFC3SYJYDZT7K67VZ75HPJVIEUVNIXF47ZG2FB2RMQQVU2HHGCYSC";

export const PLACEHOLDER = true;

interface ContractRecord {
  doctor: string;
  timestamp: string;
  data_hash: string;
  record_type: string;
  notes: string;
}

function fromContractRecord(r: ContractRecord): MedRecord {
  return {
    doctor: r.doctor,
    timestamp: r.timestamp,
    dataHash: r.data_hash,
    recordType: r.record_type,
    notes: r.notes,
  };
}

export async function getPatientRecords(
  _patientAddress: string
): Promise<MedRecord[]> {
  const req = {
    jsonrpc: "2.0",
    id: 1,
    method: "simulateTransaction",
    params: {
      transaction: "AA...",
    },
  };

  const demo: ContractRecord[] = [
    {
      doctor: "GA4Q...7XYZ",
      timestamp: "1715875200",
      data_hash: "0xabc123def456",
      record_type: "lab_result",
      notes: "CBC: WBC 7.2, RBC 5.1, Hgb 14.5, Hct 42%. All values within normal range.",
    },
    {
      doctor: "GA4Q...7XYZ",
      timestamp: "1715788800",
      data_hash: "0xdef789ghi012",
      record_type: "diagnosis",
      notes: "Diagnosis: Essential hypertension (I10). BP 140/90. Prescribed lifestyle modifications and follow-up in 3 months.",
    },
    {
      doctor: "GB7K...9ABC",
      timestamp: "1715616000",
      data_hash: "0xghi345jkl678",
      record_type: "vaccination",
      notes: "Administered: Tdap booster, Influenza (seasonal). No adverse reactions observed post-administration.",
    },
    {
      doctor: "GB7K...9ABC",
      timestamp: "1715356800",
      data_hash: "0xjkl901mno234",
      record_type: "imaging",
      notes: "Chest X-ray PA view: Clear lung fields bilaterally. No pleural effusion. Normal cardiac silhouette.",
    },
    {
      doctor: "GA4Q...7XYZ",
      timestamp: "1715011200",
      data_hash: "0xmno567pqr890",
      record_type: "prescription",
      notes: "Rx: Lisinopril 10mg PO daily #30, refills: 3. Amlodipine 5mg PO daily #30, refills: 3.",
    },
  ];

  return demo.map(fromContractRecord);
}

export async function getAuthorizedDoctors(
  _patientAddress: string
): Promise<string[]> {
  const demos = [
    "GA4QBNA2K7LQDTEZBJFDPW6JBCWMNFMKW2CG7NDR4ZLXFGZBXCAJ7XYZ",
    "GB7KNYWGBOBK5J4FQY3ZP3VXXP6CMWIVFGP7NMGJTT7EES7LKAFL9ABC",
  ];
  return demos;
}

export async function isDoctorAuthorized(
  patientAddress: string,
  doctorAddress: string
): Promise<boolean> {
  const doctors = await getAuthorizedDoctors(patientAddress);
  return doctors.includes(doctorAddress);
}
