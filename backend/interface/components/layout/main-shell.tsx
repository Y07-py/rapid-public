"use client";

import { cn } from "@/lib/utils";
import { ReactNode, useState } from "react";
import { SideMenu } from "./side-menu";
import { MainHeader } from "./header";

export function MainShell({ children }: { children: ReactNode }) {
    const [isCollapsed, setIsCollapsed] = useState(false);

    return (
        <div className="flex h-screen overflow-hidden">
            <aside className={cn("hidden md:block border-r bg-background transition-all duration-300", isCollapsed ? "w-16" : "w-64")}>
                <SideMenu isCollapsed={isCollapsed} />
            </aside>

            <div className="flex flex-col flex-1">
                <header className="h-16 border-b">
                    <MainHeader onToggle={() => setIsCollapsed(!isCollapsed)} isCollapsed={isCollapsed} />
                </header>
                <main className="flex-1 overflow-y-auto p-6">
                    { children }
                </main>
            </div>
        </div>
    );
}