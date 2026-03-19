"use client";

import { useEffect, useState } from "react";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardFooter, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { cn } from "@/lib/utils";
import { RefreshCcw, CheckCircle2, XCircle } from "lucide-react";

interface IdentityReport {
    id: string;
    user_id: string;
    new_image_id: string;
    identification_type: string;
    upload_at: string;
}

export default function IdentityReviewPage() {
    const [reports, setReports] = useState<IdentityReport[]>([]);
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        fetchReports();
    }, []);

    const fetchReports = async () => {
        setLoading(true);
        try {
            const res = await fetch("/admin-api/identity/list");
            if (res.ok) {
                const data = await res.json();
                setReports(data);
            }
        } catch (error) {
            console.error("Failed to fetch reports:", error);
        } finally {
            setLoading(false);
        }
    };

    const handleAction = async (report: IdentityReport, action: "approve" | "reject") => {
        const payload = {
            user_id: report.user_id,
            image_id: report.new_image_id,
            status: action,
        };

        try {
            const res = await fetch(`/admin-api/identity/review`, {
                method: "POST",
                headers: {
                    "Content-Type": "application/json",
                },
                body: JSON.stringify(payload),
            });
            if (res.ok) {
                setReports(reports.filter(r => r.id !== report.id));
            } else {
                const errorText = await res.text();
                alert(`Error: ${errorText}`);
            }
        } catch (error) {
            console.error("Failed to action report:", error);
            alert("通信エラーが発生しました。");
        }
    };

    return (
        <div className="space-y-6">
            <div className="flex items-center justify-between">
                <div>
                    <h1 className="text-2xl font-bold tracking-tight">本人確認審査 (Identity Verification Review)</h1>
                    <p className="text-muted-foreground">
                        ユーザーから提出された本人確認用書類の審査を行います。
                    </p>
                </div>
                <Button
                    variant="outline"
                    size="sm"
                    onClick={fetchReports}
                    disabled={loading}
                    className="flex items-center gap-2"
                >
                    <RefreshCcw className={cn("h-4 w-4", loading && "animate-spin")} />
                    更新
                </Button>
            </div>

            {loading ? (
                <div className="flex h-40 items-center justify-center rounded-lg border">
                    <p className="text-muted-foreground">読み込み中...</p>
                </div>
            ) : reports.length === 0 ? (
                <div className="flex h-40 items-center justify-center rounded-lg border border-dashed">
                    <p className="text-muted-foreground">現在審査が必要な申請はありません。</p>
                </div>
            ) : (
                <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
                    {reports.map((report) => (
                        <Card key={report.id} className="overflow-hidden flex flex-col">
                            <CardHeader className="p-4 border-b bg-muted/30">
                                <div className="flex justify-between items-start">
                                    <div className="space-y-1">
                                        <CardTitle className="text-sm font-bold">
                                            {report.identification_type === "drivers_license" ? "運転免許証" :
                                                report.identification_type === "passport" ? "パスポート" :
                                                    report.identification_type === "my_number_card" ? "マイナンバーカード" : report.identification_type}
                                        </CardTitle>
                                        <p className="text-xs text-muted-foreground">User ID: {report.user_id.slice(0, 8)}...</p>
                                    </div>
                                    <Badge variant="secondary" className="text-[10px]">
                                        {new Date(report.upload_at).toLocaleString()}
                                    </Badge>
                                </div>
                            </CardHeader>
                            <div className="relative aspect-[3/2] bg-black">
                                <img
                                    src={`/admin-api/identity/image/${report.new_image_id}`}
                                    alt="Identity document"
                                    className="object-contain w-full h-full"
                                    onError={(e) => {
                                        (e.target as HTMLImageElement).src = 'data:image/svg+xml;charset=UTF-8,%3Csvg%20xmlns%3D%22http%3A%2F%2Fwww.w3.org%2F2000%2Fsvg%22%20width%3D%2224%22%20height%3D%2224%22%20viewBox%3D%220%200%2024%2024%22%20fill%3D%22none%22%20stroke%3D%22currentColor%22%20stroke-width%3D%222%22%20stroke-linecap%3D%22round%22%20stroke-linejoin%3D%22round%22%3E%3Crect%20width%3D%2218%22%20height%3D%2218%22%20x%3D%223%22%20y%3D%223%22%20rx%3D%222%22%20ry%3D%222%22%2F%3E%3Ccircle%20cx%3D%229%22%20cy%3D%229%22%20r%3D%222%22%2F%3E%3Cpath%20d%3D%22m21%2015-3.086-3.086a2%202%200%200%200-2.828%200L6%2021%22%2F%3E%3C%2Fsvg%3E';
                                    }}
                                />
                            </div>
                            <CardContent className="p-4 flex-1">
                                <p className="text-xs text-muted-foreground leading-relaxed">
                                    書類の種類が指定されたものと一致しているか、写真が鮮明であるかを確認してください。
                                </p>
                            </CardContent>
                            <CardFooter className="p-4 bg-muted/50 flex gap-2 border-t">
                                <Button
                                    variant="outline"
                                    size="sm"
                                    className="flex-1 text-red-600 hover:text-red-700 hover:bg-red-50 gap-2 font-bold"
                                    onClick={() => handleAction(report, "reject")}
                                >
                                    <XCircle className="h-4 w-4" />
                                    不備あり
                                </Button>
                                <Button
                                    size="sm"
                                    className="flex-1 bg-green-600 hover:bg-green-700 gap-2 font-bold"
                                    onClick={() => handleAction(report, "approve")}
                                >
                                    <CheckCircle2 className="h-4 w-4" />
                                    承認
                                </Button>
                            </CardFooter>
                        </Card>
                    ))}
                </div>
            )}
        </div>
    );
}
