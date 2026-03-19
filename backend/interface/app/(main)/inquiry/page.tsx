"use client";

import { useEffect, useState } from "react";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { cn } from "@/lib/utils";
import { RefreshCcw, Mail, User, Calendar, MessageSquare } from "lucide-react";

interface InquiryMessage {
    id: string;
    user_id: string;
    inquiry_type: string;
    message: string;
    send_date: string;
}

export default function InquiryPage() {
    const [messages, setMessages] = useState<InquiryMessage[]>([]);
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        fetchMessages();
    }, []);

    const fetchMessages = async () => {
        setLoading(true);
        try {
            const res = await fetch("/admin-api/inquiry/list");
            if (res.ok) {
                const data = await res.json();
                setMessages(data);
            }
        } catch (error) {
            console.error("Failed to fetch inquiry messages:", error);
        } finally {
            setLoading(false);
        }
    };

    const formatDate = (dateString: string) => {
        const date = new Date(dateString);
        return new Intl.DateTimeFormat("ja-JP", {
            year: "numeric",
            month: "2-digit",
            day: "2-digit",
            hour: "2-digit",
            minute: "2-digit",
        }).format(date);
    };

    return (
        <div className="space-y-6">
            <div className="flex items-center justify-between">
                <div>
                    <h1 className="text-2xl font-bold tracking-tight">お問い合わせ管理 (Inquiries)</h1>
                    <p className="text-muted-foreground">
                        ユーザーから送信されたお問い合わせメッセージの一覧です。
                    </p>
                </div>
                <Button
                    variant="outline"
                    size="sm"
                    onClick={fetchMessages}
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
            ) : messages.length === 0 ? (
                <div className="flex h-40 items-center justify-center rounded-lg border border-dashed">
                    <p className="text-muted-foreground">お問い合わせメッセージはありません。</p>
                </div>
            ) : (
                <div className="grid grid-cols-1 gap-6">
                    {messages.map((msg) => (
                        <Card key={msg.id} className="overflow-hidden">
                            <CardHeader className="bg-muted/30 pb-4">
                                <div className="flex items-center justify-between">
                                    <div className="flex items-center gap-3">
                                        <Badge variant="secondary" className="px-2.5 py-0.5 text-xs">
                                            {msg.inquiry_type}
                                        </Badge>
                                        <span className="text-xs text-muted-foreground flex items-center gap-1">
                                            <Calendar className="h-3 w-3" />
                                            {formatDate(msg.send_date)}
                                        </span>
                                    </div>
                                    <div className="text-xs text-muted-foreground flex items-center gap-1 font-mono">
                                        <User className="h-3 w-3" />
                                        {msg.user_id}
                                    </div>
                                </div>
                            </CardHeader>
                            <CardContent className="p-6">
                                <div className="flex gap-4">
                                    <div className="mt-1">
                                        <MessageSquare className="h-5 w-5 text-muted-foreground" />
                                    </div>
                                    <div className="flex-1 space-y-2">
                                        <p className="text-sm leading-relaxed whitespace-pre-wrap">
                                            {msg.message}
                                        </p>
                                    </div>
                                </div>
                            </CardContent>
                        </Card>
                    ))}
                </div>
            )}
        </div>
    );
}
