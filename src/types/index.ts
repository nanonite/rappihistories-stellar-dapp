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
  lab_result: "Resultado de Laboratorio",
  prescription: "Receta",
  diagnosis: "Diagnóstico",
  vaccination: "Vacunación",
  imaging: "Imagenología",
  surgery: "Cirugía",
  referral: "Referencia",
  discharge: "Resumen de Alta",
  visit_note: "Nota de Consulta",
  other: "Otro",
};
