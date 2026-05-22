"use client";

import { useState } from "react";
import { shortAddress } from "@/lib/stellar";

interface DoctorManagerProps {
  doctors: string[];
  onAdd: (address: string) => void;
  onRemove: (address: string) => void;
  disabled?: boolean;
}

export function DoctorManager({
  doctors,
  onAdd,
  onRemove,
  disabled,
}: DoctorManagerProps) {
  const [newDoctor, setNewDoctor] = useState("");

  const handleAdd = () => {
    if (newDoctor.trim()) {
      onAdd(newDoctor.trim());
      setNewDoctor("");
    }
  };

  return (
    <div className="card">
      <h2 className="text-lg font-semibold text-gray-800 mb-4">
        Authorized Doctors
      </h2>

      <div className="flex gap-2 mb-4">
        <input
          type="text"
          value={newDoctor}
          onChange={(e) => setNewDoctor(e.target.value)}
          placeholder="GABC...DEF"
          className="input flex-1 text-sm font-mono"
          disabled={disabled}
        />
        <button onClick={handleAdd} disabled={disabled || !newDoctor.trim()} className="btn-primary text-sm">
          Authorize
        </button>
      </div>

      {doctors.length === 0 ? (
        <p className="text-sm text-gray-400 py-2">No authorized doctors yet.</p>
      ) : (
        <ul className="divide-y divide-gray-100">
          {doctors.map((doc) => (
            <li
              key={doc}
              className="flex items-center justify-between py-2.5"
            >
              <div className="flex items-center gap-3">
                <div className="w-8 h-8 rounded-full bg-medical-100 flex items-center justify-center">
                  <span className="text-xs font-bold text-medical-700">D</span>
                </div>
                <span className="text-sm font-mono text-gray-700">
                  {shortAddress(doc)}
                </span>
              </div>
              <button
                onClick={() => onRemove(doc)}
                disabled={disabled}
                className="text-xs text-red-500 hover:text-red-700 font-medium disabled:opacity-50"
              >
                Revoke
              </button>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
