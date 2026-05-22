"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { shortAddress } from "@/lib/stellar";
import { useWallet } from "@/hooks/useWallet";

export function Navbar() {
  const pathname = usePathname();
  const { wallet, connect, disconnect } = useWallet();

  return (
    <nav className="bg-white border-b border-gray-200 sticky top-0 z-50">
      <div className="max-w-6xl mx-auto px-4 h-16 flex items-center justify-between">
        <div className="flex items-center gap-8">
          <Link href="/" className="font-bold text-xl text-primary-700">
            MediChain
          </Link>
          <div className="hidden sm:flex items-center gap-1">
            <Link
              href="/dashboard"
              className={`px-3 py-2 rounded-md text-sm font-medium transition-colors ${
                pathname === "/dashboard"
                  ? "bg-primary-50 text-primary-700"
                  : "text-gray-600 hover:text-gray-900 hover:bg-gray-50"
              }`}
            >
              My Records
            </Link>
            <Link
              href="/doctor"
              className={`px-3 py-2 rounded-md text-sm font-medium transition-colors ${
                pathname === "/doctor"
                  ? "bg-primary-50 text-primary-700"
                  : "text-gray-600 hover:text-gray-900 hover:bg-gray-50"
              }`}
            >
              Doctor Portal
            </Link>
          </div>
        </div>

        <div className="flex items-center gap-3">
          {wallet.connected ? (
            <div className="flex items-center gap-2">
              <span className="text-xs bg-green-100 text-green-700 px-2 py-1 rounded-full font-mono">
                {shortAddress(wallet.publicKey!)}
              </span>
              <button onClick={disconnect} className="text-xs text-gray-500 hover:text-red-600">
                Disconnect
              </button>
            </div>
          ) : (
            <button
              onClick={() => {
                const pk = prompt("Enter Stellar public key for demo:");
                if (pk) connect(pk);
              }}
              className="btn-primary text-sm"
            >
              Connect Wallet
            </button>
          )}
        </div>
      </div>
    </nav>
  );
}
