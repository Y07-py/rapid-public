"use client";

import { SignInButton, UserButton } from "@clerk/nextjs";

export function Header({ isLoggedIn }: { isLoggedIn: boolean }) {
  return (
    <header className="flex justify-between items-center p-4 border-b bg-white dark:bg-black/50 backdrop-blur-md">
      <h1 className="text-xl font-bold">Activity Log Admin</h1>
      <div>
        {isLoggedIn ? (
          <div className="flex items-center gap-4">
            <UserButton showName />
          </div>
        ) : (
          <SignInButton mode="modal" />
        )}
      </div>
    </header>
  );
}
