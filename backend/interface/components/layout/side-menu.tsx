import { cn } from "@/lib/utils";
import Link from "next/link";
import { Image as ImageIcon, CheckSquare, Mail, Settings, AlertTriangle } from "lucide-react";

export function SideMenu({ isCollapsed }: { isCollapsed: boolean }) {
    return (
        <div className="flex flex-col h-full">
            <div className={cn("p-6", isCollapsed && "px-4")}>
                <h2 className={cn("font-bold transition-all", isCollapsed ? "opacity-0" : "opacity-100")}>
                    {isCollapsed ? "R" : "Rapid Admin"}
                </h2>
            </div>

            <nav className="flex-1 px-4 py-4 space-y-2">
                <Link href="/review" className={cn(
                    "flex items-center gap-3 px-3 py-2 rounded-lg transition-colors hover:bg-muted text-muted-foreground hover:text-foreground",
                    isCollapsed && "justify-center"
                )}>
                    <ImageIcon className="h-5 w-5 shrink-0" />
                    {!isCollapsed && <span>画像審査</span>}
                </Link>
                <Link href="/identity" className={cn(
                    "flex items-center gap-3 px-3 py-2 rounded-lg transition-colors hover:bg-muted text-muted-foreground hover:text-foreground",
                    isCollapsed && "justify-center"
                )}>
                    <CheckSquare className="h-5 w-5 shrink-0" />
                    {!isCollapsed && <span>本人確認審査</span>}
                </Link>
                <Link href="/inquiry" className={cn(
                    "flex items-center gap-3 px-3 py-2 rounded-lg transition-colors hover:bg-muted text-muted-foreground hover:text-foreground",
                    isCollapsed && "justify-center"
                )}>
                    <Mail className="h-5 w-5 shrink-0" />
                    {!isCollapsed && <span>お問い合わせ</span>}
                </Link>
                <Link href="/report" className={cn(
                    "flex items-center gap-3 px-3 py-2 rounded-lg transition-colors hover:bg-muted text-muted-foreground hover:text-foreground",
                    isCollapsed && "justify-center"
                )}>
                    <AlertTriangle className="h-5 w-5 shrink-0" />
                    {!isCollapsed && <span>通報履歴</span>}
                </Link>
                <Link href="/settings" className={cn(
                    "flex items-center gap-3 px-3 py-2 rounded-lg transition-colors hover:bg-muted text-muted-foreground hover:text-foreground",
                    isCollapsed && "justify-center"
                )}>
                    <Settings className="h-5 w-5 shrink-0" />
                    {!isCollapsed && <span>サーバー設定</span>}
                </Link>
            </nav>
        </div>
    );
}