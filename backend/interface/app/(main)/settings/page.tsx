"use client";

import { useEffect, useState } from "react";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { AlertTriangle, Server, ShieldAlert, Zap, Loader2 } from "lucide-react";


export default function SettingsPage() {
    const [isMaintenance, setIsMaintenance] = useState(false);
    const [isLoading, setIsLoading] = useState(false);

    useEffect(() => {
        const fetchStatus = async () => {
            try {
                const res = await fetch(`/admin-api/system/maintenance`);
                if (res.ok) {
                    const data = await res.json();
                    setIsMaintenance(data.is_maintenance);
                }
            } catch (err) {
                console.error("Failed to fetch maintenance status:", err);
            }
        };
        fetchStatus();
    }, []);

    const handleToggle = async () => {
        setIsLoading(true);
        try {
            const nextMode = !isMaintenance;
            const res = await fetch(`/admin-api/system/maintenance`, {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({ is_maintenance: nextMode })
            });
            if (res.ok) {
                setIsMaintenance(nextMode);
            } else {
                console.error("Failed to toggle maintenance mode:", res.statusText);
                alert("メンテナンスモードの切り替えに失敗しました。");
            }
        } catch (err) {
            console.error("Error toggling maintenance mode:", err);
            alert("通信エラーが発生しました。");
        } finally {
            setIsLoading(false);
        }
    };

    return (
        <div className="container mx-auto p-8 space-y-8 animate-in fade-in duration-500">
            <div className="flex items-center justify-between">
                <div>
                    <h1 className="text-3xl font-bold tracking-tight">サーバー設定</h1>
                    <p className="text-muted-foreground mt-2">
                        システム全体の動作モードやメンテナンスの管理を行います。
                    </p>
                </div>
                <Badge variant={isMaintenance ? "destructive" : "outline"} className="px-4 py-1.5 text-sm font-medium">
                    {isMaintenance ? "メンテナンスモード実行中" : "通常稼働中"}
                </Badge>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
                {/* メンテナンスモード設定カード */}
                <Card className="border-2 transition-all hover:shadow-lg">
                    <CardHeader className="pb-4">
                        <div className="flex items-center gap-3 mb-2">
                            <div className={`p-2 rounded-lg ${isMaintenance ? "bg-destructive/10 text-destructive" : "bg-primary/10 text-primary"}`}>
                                <ShieldAlert className="h-6 w-6" />
                            </div>
                            <CardTitle>メンテナンスモード</CardTitle>
                        </div>
                        <CardDescription>
                            有効にすると、iOSアプリからの一般リクエストを遮断し、ユーザーにメンテナンス画面を表示します。
                        </CardDescription>
                    </CardHeader>
                    <CardContent className="space-y-6">
                        <div className="p-4 rounded-xl bg-muted/50 border space-y-3">
                            <div className="flex items-start gap-3">
                                <AlertTriangle className="h-5 w-5 text-warning shrink-0 mt-0.5" />
                                <div className="text-sm">
                                    <p className="font-semibold">実行前の注意</p>
                                    <ul className="text-muted-foreground list-disc list-inside mt-1 ml-1 space-y-1">
                                        <li>現在ログイン中のユーザーも切断されます。</li>
                                        <li>実施予定時刻の15分前からの有効化を推奨します。</li>
                                        <li>この設定は即座に反映されます。</li>
                                    </ul>
                                </div>
                            </div>
                        </div>

                        <div className="flex items-center justify-between pt-4 border-t">
                            <div className="space-y-0.5">
                                <p className="font-medium">メンテナンスを有効にする</p>
                                <p className="text-sm text-muted-foreground">
                                    {isMaintenance ? "全サービスを通常稼働に戻します" : "サービスを停止してメンテナンス状態にします"}
                                </p>
                            </div>
                            <Button 
                                variant={isMaintenance ? "outline" : "destructive"}
                                size="lg"
                                className="px-8 font-bold transition-all active:scale-95 min-w-[160px]"
                                onClick={handleToggle}
                                disabled={isLoading}
                            >
                                {isLoading ? (
                                    <>
                                        <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                                        処理中...
                                    </>
                                ) : (
                                    isMaintenance ? "メンテナンス終了" : "緊急メンテナンス開始"
                                )}
                            </Button>
                        </div>
                    </CardContent>
                </Card>

                {/* 他の設定（将来用） */}
                <Card className="border-2 border-dashed opacity-60">
                    <CardHeader>
                        <div className="flex items-center gap-3 mb-2">
                            <div className="p-2 rounded-lg bg-muted text-muted-foreground">
                                <Server className="h-6 w-6" />
                            </div>
                            <CardTitle>キャパシティ管理 (Coming Soon)</CardTitle>
                        </div>
                        <CardDescription>
                            同時接続数やレート制限の動的な変更が可能になります。
                        </CardDescription>
                    </CardHeader>
                    <CardContent className="h-[200px] flex items-center justify-center">
                        <div className="text-center space-y-2">
                            <Zap className="h-8 w-8 text-muted mx-auto" />
                            <p className="text-sm font-medium text-muted-foreground">
                                機能開発中...
                            </p>
                        </div>
                    </CardContent>
                </Card>
            </div>
        </div>
    );
}
