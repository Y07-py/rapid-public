"use client";

import { useEffect, useState } from "react";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardFooter, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { cn } from "@/lib/utils";
import { RefreshCcw } from "lucide-react";


interface Label {
    description: string;
    score: number;
}

interface SafeSearch {
    adult: string;
    spoof: string;
    medical: string;
    violence: string;
    racy: string;
}

interface ReportPayload {
    image_id: string;
    user_id: string;
    safe_search: SafeSearch;
    labels: Label[] | null;
}

export default function ReviewPage() {
    const [reports, setReports] = useState<ReportPayload[]>([]);
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        fetchReports();
    }, []);

    const fetchReports = async () => {
        setLoading(true);
        try {
            const res = await fetch("/admin-api/review/list");
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

    const generateUUID = () => {
        if (typeof crypto !== 'undefined' && crypto.randomUUID) {
            return crypto.randomUUID();
        }
        return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (c) => {
            const r = Math.random() * 16 | 0;
            const v = c === 'x' ? r : (r & 0x3 | 0x8);
            return v.toString(16);
        });
    };

    const handleAction = async (imageId: string, userId: string, action: "approve" | "reject") => {
        const message = action === "approve"
            ? "プロフィール画像が承認されました。"
            : "プロフィール画像が不適切と判断されたため、削除されました。";

        const payload = {
            review_id: generateUUID(),
            user_id: userId,
            message: message,
            image_id: imageId,
            message_at: new Date().toISOString(),
            status: action,
        };

        try {
            const res = await fetch(`/admin-api/review/action`, {
                method: "POST",
                headers: {
                    "Content-Type": "application/json",
                },
                body: JSON.stringify(payload),
            });
            if (res.ok) {
                setReports(reports.filter(r => r.image_id !== imageId));
            } else {
                const errorText = await res.text();
                alert(`Error: ${errorText}`);
            }
        } catch (error) {
            console.error("Failed to action report:", error);
            alert("通信エラーが発生しました。");
        }
    };

    const getColorForLevel = (level: string) => {
        switch (level) {
            case "VERY_UNLIKELY": return "bg-green-100 text-green-800";
            case "UNLIKELY": return "bg-green-50 text-green-700";
            case "POSSIBLE": return "bg-yellow-100 text-yellow-800";
            case "LIKELY": return "bg-orange-100 text-orange-800";
            case "VERY_LIKELY": return "bg-red-100 text-red-800";
            default: return "bg-gray-100 text-gray-800";
        }
    };

    return (
        <div className="space-y-6">
            <div className="flex items-center justify-between">
                <div>
                    <h1 className="text-2xl font-bold tracking-tight">画像審査 (Image Review)</h1>
                    <p className="text-muted-foreground">
                        Google Cloud Vision API によって不適切(POSSIBLE以上)と判定された画像一覧です。
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
                    <p className="text-muted-foreground">現在審査が必要な画像はありません。</p>
                </div>
            ) : (
                <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-6">
                    {reports.map((report) => (
                        <Card key={report.image_id} className="overflow-hidden flex flex-col">
                            <div className="relative aspect-square bg-muted">
                                <img
                                    src={`/admin-api/review/image/${report.image_id}`}
                                    alt="Review content"
                                    className="object-cover w-full h-full"
                                    onError={(e) => {
                                        (e.target as HTMLImageElement).src = 'data:image/svg+xml;charset=UTF-8,%3Csvg%20xmlns%3D%22http%3A%2F%2Fwww.w3.org%2F2000%2Fsvg%22%20width%3D%2224%22%20height%3D%2224%22%20viewBox%3D%220%200%2024%2024%22%20fill%3D%22none%22%20stroke%3D%22currentColor%22%20stroke-width%3D%222%22%20stroke-linecap%3D%22round%22%20stroke-linejoin%3D%22round%22%3E%3Crect%20width%3D%2218%22%20height%3D%2218%22%20x%3D%223%22%20y%3D%223%22%20rx%3D%222%22%20ry%3D%222%22%2F%3E%3Ccircle%20cx%3D%229%22%20cy%3D%229%22%20r%3D%222%22%2F%3E%3Cpath%20d%3D%22m21%2015-3.086-3.086a2%202%200%200%200-2.828%200L6%2021%22%2F%3E%3C%2Fsvg%3E';
                                    }}
                                />
                            </div>
                            <CardContent className="p-4 flex-1 space-y-4">
                                <div>
                                    <h3 className="text-sm font-medium mb-2">Safe Search Status</h3>
                                    <div className="flex flex-wrap gap-2">
                                        {(Object.entries(report.safe_search) as [keyof SafeSearch, string][]).map(([key, value]) => (
                                            <Badge key={key} variant="outline" className={cn("text-xs font-normal border-transparent", getColorForLevel(value))}>
                                                {key}: {value}
                                            </Badge>
                                        ))}
                                    </div>
                                </div>

                                {report.labels && report.labels.length > 0 && (
                                    <div>
                                        <h3 className="text-sm font-medium mb-2">Labels Detected</h3>
                                        <p className="text-xs text-muted-foreground leading-relaxed">
                                            {report.labels.slice(0, 5).map(l => `${l.description} (${Math.round(l.score * 100)}%)`).join(', ')}
                                            {report.labels.length > 5 && " ..."}
                                        </p>
                                    </div>
                                )}
                            </CardContent>
                            <CardFooter className="p-4 bg-muted/50 flex gap-2 border-t">
                                <Button
                                    variant="outline"
                                    className="flex-1 text-red-600 hover:text-red-700 hover:bg-red-50"
                                    onClick={() => handleAction(report.image_id, report.user_id, "reject")}
                                >
                                    削除 (Reject)
                                </Button>
                                <Button
                                    className="flex-1"
                                    onClick={() => handleAction(report.image_id, report.user_id, "approve")}
                                >
                                    承認 (Approve)
                                </Button>
                            </CardFooter>
                        </Card>
                    ))}
                </div>
            )}
        </div>
    );
}
