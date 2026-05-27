"use client";

import { useEffect, useState } from "react";
import { useWallet } from "@/hooks/useWallet";
import { getPatientRecords, getAuthorizedDoctors } from "@/lib/contract";
import { RecordCard } from "@/components/RecordCard";
import { DoctorManager } from "@/components/DoctorManager";
import { MedRecord } from "@/types";
import { shortAddress } from "@/lib/stellar";
import Link from "next/link";

export default function PatientDashboard() {
  const { wallet } = useWallet();
  const [records, setRecords] = useState<MedRecord[]>([]);
  const [doctors, setDoctors] = useState<string[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!wallet.publicKey) {
      setLoading(false);
      return;
    }

    Promise.all([
      getPatientRecords(wallet.publicKey),
      getAuthorizedDoctors(wallet.publicKey),
    ]).then(([r, d]) => {
      setRecords(r);
      setDoctors(d);
      setLoading(false);
    });
  }, [wallet.publicKey]);

  if (!wallet.connected) {
    return (
      <div className="flex flex-col items-center justify-center pt-24 text-center">
        <div className="w-16 h-16 rounded-full bg-gray-100 flex items-center justify-center mb-4">
          <svg className="w-8 h-8 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
            <path strokeLinecap="round" strokeLinejoin="round" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
          </svg>
        </div>
        <h2 className="text-xl font-semibold text-gray-700 mb-2">
          Conecta tu billetera
        </h2>
        <p className="text-sm text-gray-500 mb-6">
          Usa el botón Conectar en la barra de navegación para ver tus registros médicos.
        </p>
        <Link href="/" className="btn-secondary text-sm">
          Volver al Inicio
        </Link>
      </div>
    );
  }

  if (loading) {
    return (
      <div className="flex items-center justify-center pt-24">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary-600" />
      </div>
    );
  }

  return (
    <div className="space-y-8">
      <div>
        <h1 className="text-2xl font-bold text-gray-900">Mis Registros Médicos</h1>
        <p className="text-sm text-gray-500 mt-1">
          Paciente:{" "}
          <span className="font-mono text-gray-700">
            {shortAddress(wallet.publicKey!)}
          </span>
        </p>
      </div>

      <div className="grid lg:grid-cols-3 gap-8">
        <div className="lg:col-span-2 space-y-4">
          <h2 className="text-lg font-semibold text-gray-800">
            Registros ({records.length})
          </h2>
          {records.length === 0 ? (
            <div className="card text-center py-12">
              <p className="text-gray-400">No se encontraron registros médicos.</p>
              <p className="text-sm text-gray-400 mt-1">
                Tus registros aparecerán aquí cuando un doctor los añada.
              </p>
            </div>
          ) : (
            <div className="space-y-3">
              {records.map((record, i) => (
                <RecordCard key={i} record={record} />
              ))}
            </div>
          )}
        </div>

        <div>
          <DoctorManager
            doctors={doctors}
            onAdd={(addr) => setDoctors([...doctors, addr])}
            onRemove={(addr) =>
              setDoctors(doctors.filter((d) => d !== addr))
            }
          />
        </div>
      </div>
    </div>
  );
}
