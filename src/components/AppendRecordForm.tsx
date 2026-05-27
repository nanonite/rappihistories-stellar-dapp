"use client";

import { useState } from "react";
import { RecordType, RECORD_TYPE_LABELS } from "@/types";

interface AppendRecordFormProps {
  patientAddress: string;
  onSubmit: (data: {
    recordType: RecordType;
    dataHash: string;
    notes: string;
  }) => void;
  disabled?: boolean;
}

export function AppendRecordForm({
  patientAddress,
  onSubmit,
  disabled,
}: AppendRecordFormProps) {
  const [recordType, setRecordType] = useState<RecordType>("visit_note");
  const [dataHash, setDataHash] = useState("");
  const [notes, setNotes] = useState("");

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!notes.trim()) return;
    onSubmit({
      recordType,
      dataHash: dataHash || `0x${Date.now().toString(16)}`,
      notes: notes.trim(),
    });
    setNotes("");
    setDataHash("");
  };

  return (
    <form onSubmit={handleSubmit} className="card">
      <h2 className="text-lg font-semibold text-gray-800 mb-4">
        Añadir Registro Médico
      </h2>

      <div className="space-y-4">
        <div>
          <label className="block text-sm font-medium text-gray-600 mb-1">
            Tipo de Registro
          </label>
          <select
            value={recordType}
            onChange={(e) => setRecordType(e.target.value as RecordType)}
            className="input text-sm"
            disabled={disabled}
          >
            {Object.entries(RECORD_TYPE_LABELS).map(([value, label]) => (
              <option key={value} value={value}>
                {label}
              </option>
            ))}
          </select>
        </div>

        <div>
          <label className="block text-sm font-medium text-gray-600 mb-1">
            Hash de Datos (autogenerado si está vacío)
          </label>
          <input
            type="text"
            value={dataHash}
            onChange={(e) => setDataHash(e.target.value)}
            placeholder="0x..."
            className="input text-sm font-mono"
            disabled={disabled}
          />
        </div>

        <div>
          <label className="block text-sm font-medium text-gray-600 mb-1">
            Notas Clínicas
          </label>
          <textarea
            value={notes}
            onChange={(e) => setNotes(e.target.value)}
            rows={4}
            placeholder="Ingresa observaciones clínicas, diagnóstico, plan de tratamiento..."
            className="input text-sm resize-none"
            disabled={disabled}
          />
        </div>

        <button
          type="submit"
          disabled={disabled || !notes.trim()}
          className="btn-primary w-full"
        >
          Firmar y Añadir a la Cadena
        </button>
      </div>
    </form>
  );
}
