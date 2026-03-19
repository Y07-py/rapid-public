import { MainShell } from "@/components/layout/main-shell";
import { ReactNode } from "react";

export default function MainLayout({ children }: {children: ReactNode }) {
    return (
        <MainShell>
            { children }
        </MainShell>
    );
}