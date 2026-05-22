"use client";

import { useState, useEffect, useCallback } from "react";
import { WalletState } from "@/types";

const STORAGE_KEY = "medichain_wallet";

export function useWallet() {
  const [wallet, setWallet] = useState<WalletState>({
    connected: false,
    publicKey: null,
  });

  useEffect(() => {
    const stored = localStorage.getItem(STORAGE_KEY);
    if (stored) {
      try {
        const parsed = JSON.parse(stored);
        setWallet(parsed);
      } catch {
        localStorage.removeItem(STORAGE_KEY);
      }
    }
  }, []);

  const connect = useCallback((publicKey: string) => {
    const state: WalletState = { connected: true, publicKey };
    setWallet(state);
    localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
  }, []);

  const disconnect = useCallback(() => {
    setWallet({ connected: false, publicKey: null });
    localStorage.removeItem(STORAGE_KEY);
  }, []);

  return { wallet, connect, disconnect };
}
