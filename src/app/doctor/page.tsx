"use client";

import { useState, useEffect } from "react";
import { useWallet } from "@/hooks/useWallet";
import {
  getPatientRecords,
  getAuthorizedDoctors,
  isDoctorAuthorized,
} from "@/lib/contract";
import { AppendRecordForm } from "@/components/AppendRecordForm";
import { RecordCard } from "@/components/RecordCard";
import { MedRecord } from "@/types";
import { shortAddress } from "@/lib/stellar";
import Link from "next/link";

export default function DoctorPortal() {
  const { wallet } = useWallet();
  const [patientAddress, setPatientAddress] = useState("");
  const [isAuthorized, setIsAuthorized] = useState(false);
  const [records, setRecords] = useState<MedRecord[]>([]);
  const [checking, setChecking] = useState(false);
  const [checked, setChecked] = useState(false);

  const handleCheck = async () => {
    if (!patientAddress.trim() || !wallet.publicKey) return;
    setChecking(true);
    const authorized = await isDoctorAuthorized(
      patientAddress.trim(),
      wallet.publicKey
    );
    setIsAuthorized(authorized);
    if (authorized) {
      const recs = await getPatientRecords(patientAddress.trim());
      setRecords(recs);
    }
    setChecked(true);
    setChecking(false);
  };

  const handleAppend = (data: {
    recordType: string;
    dataHash: string;
    notes: string;
  }) => {
    const newRecord: MedRecord = {
      doctor: wallet.publicKey!,
      timestamp: String(Math.floor(Date.now() / 1000)),
      dataHash: data.dataHash,
      recordType: data.recordType,
      notes: data.notes,
    };
    setRecords([newRecord, ...records]);
  };

  if (!wallet.connected) {
    return (
      <div className="flex flex-col items-center justify-center pt-24 text-center">
        <div className="w-16 h-16 rounded-full bg-medical-100 flex items-center justify-center mb-4">
          <svg className="w-8 h-8 text-medical-700" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
            <path strokeLinecap="round" strokeLinejoin="round" d="M4.26 10.147a60.436 60.436 0 00-.491 6.347A48.627 48.627 0 0112 20.904a48.627 48.627 0 018.232-4.41 60.46 60.46 0 00-.491-6.347m-15.482 0a50.57 50.57 0 00-2.658-.813A59.905 59.905 0 0112 3.493a59.902 59.902 0 0110.399 5.84c-.896.248-1.783.52-2.658.814m-15.482 0A50.697 50.697 0 0112 13.489a50.702 50.702 0 017.74-3.342M6.75 15a.75.75 0 100-1.5.75.75 0 000 1.5zm0 0v-3.675A55.378 55.378 0 0112 8.443m-7.007 11.55A5.981 5.981 0 006.75 15.75v-1.5" />
          </svg>
        </div>
        <h2 className="text-xl font-semibold text-gray-700 mb-2">
          Doctor Portal
        </h2>
        <p className="text-sm text-gray-500 mb-6">
          Connect your wallet to access patient records.
        </p>
        <Link href="/" className="btn-secondary text-sm">
          Back to Home
        </Link>
      </div>
    );
  }

  return (
    <div className="space-y-8 max-w-3xl mx-auto">
      <div>
        <h1 className="text-2xl font-bold text-gray-900">Doctor Portal</h1>
        <p className="text-sm text-gray-500 mt-1">
          Signed in as:{" "}
          <span className="font-mono text-gray-700">
            {shortAddress(wallet.publicKey!)}
          </span>
        </p>
      </div>

      <div className="card">
        <h2 className="text-lg font-semibold text-gray-800 mb-3">
          Look Up Patient
        </h2>
        <div className="flex gap-2">
          <input
            type="text"
            value={patientAddress}
            onChange={(e) => {
              setPatientAddress(e.target.value);
              setChecked(false);
              setIsAuthorized(false);
              setRecords([]);
            }}
            placeholder="Patient Stellar address..."
            className="input flex-1 text-sm font-mono"
          />
          <button
            onClick={handleCheck}
            disabled={checking || !patientAddress.trim()}
            className="btn-primary text-sm"
          >
            {checking ? "Checking..." : "Look Up"}
          </button>
        </div>

        {checked && !isAuthorized && (
          <div className="mt-4 p-4 bg-amber-50 border border-amber-200 rounded-lg">
            <p className="text-sm text-amber-800">
              You are not authorized to view or append records for this
              patient. Ask the patient to authorize your address.
            </p>
          </div>
        )}
      </div>

      {isAuthorized && (
        <>
          <AppendRecordForm
            patientAddress={patientAddress}
            onSubmit={handleAppend}
          />

          <div className="space-y-4">
            <h2 className="text-lg font-semibold text-gray-800">
              Patient Records ({records.length})
            </h2>
            {records.length === 0 ? (
              <div className="card text-center py-12">
                <p className="text-gray-400">No records yet for this patient.</p>
              </div>
            ) : (
              <div className="space-y-3">
                {records.map((record, i) => (
                  <RecordCard key={i} record={record} />
                ))}
              </div>
            )}
          </div>
        </>
      )}
    </div>
  );
}
