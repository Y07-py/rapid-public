"use client";

import { useEffect, useState } from "react";
import { Menu } from "lucide-react";
import { Button } from "../ui/button";
import { Sheet, SheetContent, SheetHeader, SheetTitle, SheetTrigger } from "../ui/sheet";


export function MainHeader({ onToggle, isCollapsed }: { onToggle: () => void, isCollapsed: boolean}) {
    const [isMounted, setIsMounted] = useState(false);

    useEffect(() => {
        setIsMounted(true);
    }, []);
    return (
        <div className="flex items-center h-full px-4 justify-between">
            <div className="flex items-center gap-4">
                <Button variant={"ghost"} size={"icon"} onClick={onToggle} className="hidden md:flex">
                    <Menu className="h-6 w-6" />
                </Button>

                <div className="md:hidden">
                    {isMounted && (
                        <Sheet>
                            <SheetTrigger asChild>
                                <Button variant={"ghost"}>
                                    <Menu className="h-6 w-6"/>
                                </Button>
                            </SheetTrigger>
                            <SheetContent side="left" className="p-0 w-64">
                                <SheetHeader className="px-6 py-4 border-b">
                                    <SheetTitle>
                                        Menu
                                    </SheetTitle>
                                </SheetHeader>
                            </SheetContent>
                        </Sheet>
                    )}
                </div>
            </div>

            <div className="flex items-center gap-4">
                <div>
                    User icon
                </div>
            </div>
        </div>
    )
}