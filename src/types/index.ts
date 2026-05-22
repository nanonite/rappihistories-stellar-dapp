export interface MedRecord {
  doctor: string;
  timestamp: string;
  dataHash: string;
  recordType: string;
  notes: string;
}

export interface Patient {
  address: string;
  authorizedDoctors: string[];
  records: MedRecord[];
}

export interface WalletState {
  connected: boolean;
  publicKey: string | null;
}

export type RecordType =
  | "lab_result"
  | "prescription"
  | "diagnosis"
  | "vaccination"
  | "imaging"
  | "surgery"
  | "referral"
  | "discharge"
  | "visit_note"
  | "other";

export const RECORD_TYPE_LABELS: Record<RecordType, string> = {
  lab_result: "Lab Result",
  prescription: "Prescription",
  diagnosis: "Diagnosis",
  vaccination: "Vaccination",
  imaging: "Imaging",
  surgery: "Surgery",
  referral: "Referral",
  discharge: "Discharge Summary",
  visit_note: "Visit Note",
  other: "Other",
};
