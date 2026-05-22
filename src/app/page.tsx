import Link from "next/link";

export default function HomePage() {
  return (
    <div className="flex flex-col items-center text-center pt-16 pb-24">
      <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-medical-50 text-medical-700 text-sm font-medium mb-6">
        Built on Stellar Soroban
      </div>

      <h1 className="text-4xl sm:text-5xl font-bold text-gray-900 tracking-tight mb-4 max-w-2xl">
        Medical Records on the{" "}
        <span className="text-primary-600">Blockchain</span>
      </h1>

      <p className="text-lg text-gray-500 max-w-xl mb-10 leading-relaxed">
        Immutable, append-only health records. Patients own their data and
        authorize which doctors can add entries. Transparent audit trail,
        cryptographic integrity.
      </p>

      <div className="flex gap-4 flex-wrap justify-center">
        <Link href="/dashboard" className="btn-primary px-6 py-3 text-base">
          Patient Dashboard
        </Link>
        <Link href="/doctor" className="btn-secondary px-6 py-3 text-base">
          Doctor Portal
        </Link>
      </div>

      <div className="grid sm:grid-cols-3 gap-6 mt-20 max-w-4xl w-full">
        <div className="card text-left">
          <div className="w-10 h-10 rounded-lg bg-primary-100 flex items-center justify-center mb-3">
            <svg className="w-5 h-5 text-primary-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
              <path strokeLinecap="round" strokeLinejoin="round" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z" />
            </svg>
          </div>
          <h3 className="font-semibold text-gray-800 mb-1">Tamper-Proof</h3>
          <p className="text-sm text-gray-500">
            Every record is cryptographically hashed and stored on-chain. Once
            written, records cannot be modified or deleted.
          </p>
        </div>

        <div className="card text-left">
          <div className="w-10 h-10 rounded-lg bg-medical-100 flex items-center justify-center mb-3">
            <svg className="w-5 h-5 text-medical-700" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
              <path strokeLinecap="round" strokeLinejoin="round" d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z" />
            </svg>
          </div>
          <h3 className="font-semibold text-gray-800 mb-1">Patient-Controlled</h3>
          <p className="text-sm text-gray-500">
            You decide which doctors can view and append to your records.
            Grant or revoke access instantly on-chain.
          </p>
        </div>

        <div className="card text-left">
          <div className="w-10 h-10 rounded-lg bg-amber-100 flex items-center justify-center mb-3">
            <svg className="w-5 h-5 text-amber-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
              <path strokeLinecap="round" strokeLinejoin="round" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2m-3 7h3m-3 4h3m-6-4h.01M9 16h.01" />
            </svg>
          </div>
          <h3 className="font-semibold text-gray-800 mb-1">Audit Trail</h3>
          <p className="text-sm text-gray-500">
            Complete history of who accessed or added records, when, and
            what changed. Full transparency for patients and auditors.
          </p>
        </div>
      </div>
    </div>
  );
}
