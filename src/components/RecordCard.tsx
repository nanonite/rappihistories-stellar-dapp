"use client";

import { MedRecord, RECORD_TYPE_LABELS, RecordType } from "@/types";
import { formatTimestamp, shortAddress } from "@/lib/stellar";

interface RecordCardProps {
  record: MedRecord;
}

export function RecordCard({ record }: RecordCardProps) {
  const typeLabel =
    RECORD_TYPE_LABELS[record.recordType as RecordType] ?? record.recordType;

  return (
    <div className="card hover:shadow-md transition-shadow">
      <div className="flex items-start justify-between mb-3">
        <div>
          <span className="inline-block px-2.5 py-0.5 rounded-full text-xs font-semibold bg-primary-100 text-primary-700">
            {typeLabel}
          </span>
          <span className="ml-2 text-xs text-gray-400 font-mono">
            {formatTimestamp(record.timestamp)}
          </span>
        </div>
        <span className="text-xs text-gray-400 font-mono">
          #{record.dataHash.slice(0, 10)}
        </span>
      </div>

      <p className="text-sm text-gray-700 leading-relaxed mb-3">
        {record.notes}
      </p>

      <div className="flex items-center gap-2 text-xs text-gray-500 border-t border-gray-100 pt-3">
        <span className="font-medium text-gray-400">Doctor:</span>
        <span className="font-mono">{shortAddress(record.doctor)}</span>
      </div>
    </div>
  );
}
