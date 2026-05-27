import Link from "next/link";
import { ElenaWorkflowStatus } from "@/components/ElenaWorkflowStatus";

export default function HomePage() {
  return (
    <div className="flex flex-col items-center text-center pt-16 pb-24">
      <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-medical-50 text-medical-700 text-sm font-medium mb-6">
        Construido sobre Stellar Soroban
      </div>

      <h1 className="text-4xl sm:text-5xl font-bold text-gray-900 tracking-tight mb-4 max-w-2xl">
        Registros Médicos en la{" "}
        <span className="text-primary-600">Blockchain</span>
      </h1>

      <p className="text-lg text-gray-500 max-w-xl mb-10 leading-relaxed">
        Registros de salud inmutables y de solo añadir. Los pacientes son dueños de sus datos y
        autorizan qué doctores pueden añadir entradas. Registro de auditoría transparente,
        integridad criptográfica.
      </p>

      <div className="flex gap-4 flex-wrap justify-center">
        <Link href="/dashboard" className="btn-primary px-6 py-3 text-base">
          Panel del Paciente
        </Link>
        <Link href="/doctor" className="btn-secondary px-6 py-3 text-base">
          Portal del Doctor
        </Link>
      </div>

      <div className="grid sm:grid-cols-3 gap-6 mt-20 max-w-4xl w-full">
        <div className="card text-left">
          <div className="w-10 h-10 rounded-lg bg-primary-100 flex items-center justify-center mb-3">
            <svg className="w-5 h-5 text-primary-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
              <path strokeLinecap="round" strokeLinejoin="round" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z" />
            </svg>
          </div>
          <h3 className="font-semibold text-gray-800 mb-1">A Prueba de Manipulación</h3>
          <p className="text-sm text-gray-500">
            Cada registro tiene un hash criptográfico y se almacena en cadena. Una vez
            escrito, los registros no pueden ser modificados ni eliminados.
          </p>
        </div>

        <div className="card text-left">
          <div className="w-10 h-10 rounded-lg bg-medical-100 flex items-center justify-center mb-3">
            <svg className="w-5 h-5 text-medical-700" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
              <path strokeLinecap="round" strokeLinejoin="round" d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z" />
            </svg>
          </div>
          <h3 className="font-semibold text-gray-800 mb-1">Control del Paciente</h3>
          <p className="text-sm text-gray-500">
            Tú decides qué doctores pueden ver y añadir a tus registros.
            Concede o revoca acceso al instante en cadena.
          </p>
        </div>

        <div className="card text-left">
          <div className="w-10 h-10 rounded-lg bg-amber-100 flex items-center justify-center mb-3">
            <svg className="w-5 h-5 text-amber-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
              <path strokeLinecap="round" strokeLinejoin="round" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2m-3 7h3m-3 4h3m-6-4h.01M9 16h.01" />
            </svg>
          </div>
          <h3 className="font-semibold text-gray-800 mb-1">Registro de Auditoría</h3>
          <p className="text-sm text-gray-500">
            Historial completo de quién accedió o añadió registros, cuándo y
            qué cambió. Transparencia total para pacientes y auditores.
          </p>
        </div>
      </div>

      <section className="mt-16 max-w-4xl w-full text-left">
        <div className="flex flex-col sm:flex-row sm:items-end sm:justify-between gap-3 mb-6">
          <div>
            <p className="text-sm font-medium text-primary-600">
              Elementos del dApp
            </p>
            <h2 className="text-2xl font-bold text-gray-900">
              Tecnologías usadas para construir la experiencia
            </h2>
          </div>
          <p className="text-sm text-gray-500 max-w-md">
            Base web, conexión Stellar y componentes progresivos para mantener
            el prototipo portable y fácil de iterar.
          </p>
        </div>

        <div className="grid sm:grid-cols-2 lg:grid-cols-4 gap-4">
          <div className="card">
            <h3 className="font-semibold text-gray-800 mb-1">Next.js</h3>
            <p className="text-sm text-gray-500">
              Aplicación React con App Router para los flujos de paciente,
              doctor y farmacia.
            </p>
          </div>

          <div className="card">
            <h3 className="font-semibold text-gray-800 mb-1">Stellar Soroban</h3>
            <p className="text-sm text-gray-500">
              Capa de contratos, permisos, auditoría y reservas conectadas al
              ciclo de receta.
            </p>
          </div>

          <div className="card">
            <h3 className="font-semibold text-gray-800 mb-1">Tailwind CSS</h3>
            <p className="text-sm text-gray-500">
              Sistema visual rápido para pantallas clínicas claras y
              consistentes.
            </p>
          </div>

          <a
            href="https://elenajs.com/"
            target="_blank"
            rel="noreferrer"
            className="card group block transition-colors hover:border-primary-200 hover:bg-primary-50/40"
          >
            <div className="flex items-center justify-between gap-3 mb-1">
              <h3 className="font-semibold text-gray-800">ElenaJS</h3>
              <span className="text-xs font-medium text-primary-600 group-hover:text-primary-700">
                elenajs.com
              </span>
            </div>
            <p className="text-sm text-gray-500">
              Web components progresivos para elementos UI reutilizables y
              compatibles entre frameworks.
            </p>
          </a>
        </div>

        <div className="mt-4">
          <ElenaWorkflowStatus />
        </div>
      </section>
    </div>
  );
}
