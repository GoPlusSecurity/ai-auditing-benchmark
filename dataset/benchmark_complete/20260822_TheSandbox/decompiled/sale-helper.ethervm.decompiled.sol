contract Contract {
    function main() {
        memory[0x40:0x60] = 0x80;
        var var0 = msg.value;
    
        if (var0) { revert(memory[0x00:0x00]); }
    
        if (msg.data.length < 0x04) { revert(memory[0x00:0x00]); }
    
        var0 = msg.data[0x00:0x20] >> 0xe0;
    
        if (var0 == 0x2032afe4) {
            // Dispatch table entry for 0x2032afe4 (unknown)
            var var1 = 0x0074;
            var var2 = 0xac531eb26ca1d21b85126de8fb87e80e09002dcf;
        
        label_0074:
            var temp0 = memory[0x40:0x60];
            memory[temp0:temp0 + 0x20] = var2 & (0x01 << 0xa0) - 0x01;
            var temp1 = memory[0x40:0x60];
            return memory[temp1:temp1 + (temp0 + 0x20) - temp1];
        } else if (var0 == 0x8da5cb5b) {
            // Dispatch table entry for owner()
            var1 = 0x0074;
            var2 = 0x00000000000000000000000067624bfadee937c9281b4f98ce18af1bee01257e;
            goto label_0074;
        } else if (var0 == 0xad5c4648) {
            // Dispatch table entry for WETH()
            var1 = 0x0074;
            var2 = (0x21 << 0x99) + 0x06;
            goto label_0074;
        } else if (var0 == 0xb704b531) {
            // Dispatch table entry for 0xb704b531 (unknown)
            var1 = 0x00d9;
            var2 = 0x00d4;
            var var3 = msg.data.length;
            var var4 = 0x04;
            var2, var3, var4 = func_04E0(var3, var4);
            var1 = func_00D4(var2, var3, var4);
            var temp2 = memory[0x40:0x60];
            memory[temp2:temp2 + 0x20] = var1;
            var1 = temp2 + 0x20;
            var temp3 = memory[0x40:0x60];
            return memory[temp3:temp3 + var1 - temp3];
        } else if (var0 == 0xfa461e33) {
            // Dispatch table entry for uniswapV3SwapCallback(int256,int256,bytes)
            var1 = 0x00fa;
            var2 = 0x00f5;
            var3 = msg.data.length;
            var4 = 0x04;
            var var5;
            var2, var3, var4, var5 = func_051F(var3, var4);
            func_00F5(var2, var3, var4, var5);
            stop();
        } else { revert(memory[0x00:0x00]); }
    }
    
    function func_00D4(var arg0, var arg1, var arg2) returns (var r0) {
        var var0 = 0x00;
        var temp0 = arg0;
        var var1 = temp0 & (0x01 << 0xa0) - 0x01;
        var var2 = 0x128acb08;
        var var3 = address(this);
        var var4 = 0x00;
        var var5 = arg1;
        var var6 = arg2;
        var temp1 = memory[0x40:0x60] + 0x20;
        memory[temp1:temp1 + 0x20] = temp0 & (0x01 << 0xa0) - 0x01;
        var var7 = temp1 + 0x20;
        var temp2 = memory[0x40:0x60];
        var temp3 = var7;
        memory[temp2:temp2 + 0x20] = temp3 - temp2 - 0x20;
        memory[0x40:0x60] = temp3;
        var temp4 = memory[0x40:0x60];
        memory[temp4:temp4 + 0x20] = (var2 & 0xffffffff) << 0xe0;
        var temp5 = var3;
        var3 = 0x015f;
        var temp6 = var4;
        var4 = temp5;
        var temp7 = var5;
        var5 = temp6;
        var temp8 = var6;
        var6 = temp7;
        var7 = temp8;
        var var8 = temp2;
        var var9 = temp4 + 0x04;
        var3 = func_0598(var4, var5, var6, var7, var8, var9);
        var temp9 = memory[0x40:0x60];
        var temp10;
        temp10, memory[temp9:temp9 + 0x40] = address(var1).call.gas(msg.gas)(memory[temp9:temp9 + var3 - temp9]);
        var4 = !temp10;
    
        if (!var4) {
            var temp11 = memory[0x40:0x60];
            var temp12 = returndata.length;
            memory[0x40:0x60] = temp11 + (temp12 + 0x1f & ~0x1f);
            var1 = 0x019e;
            var3 = temp11;
            var2 = var3 + temp12;
            var1, var2 = func_0610(var2, var3);
            var temp13 = memory[0x40:0x60];
            memory[temp13:temp13 + 0x20] = 0x70a08231 << 0xe0;
            memory[temp13 + 0x04:temp13 + 0x04 + 0x20] = address(this);
            var1 = (0x21 << 0x99) + 0x06;
            var2 = 0x70a08231;
            var3 = temp13 + 0x24;
            var temp14 = memory[0x40:0x60];
            var temp15;
            temp15, memory[temp14:temp14 + 0x20] = address(var1).staticcall.gas(msg.gas)(memory[temp14:temp14 + var3 - temp14]);
            var4 = !temp15;
        
            if (!var4) {
                var temp16 = memory[0x40:0x60];
                var temp17 = returndata.length;
                memory[0x40:0x60] = temp16 + (temp17 + 0x1f & ~0x1f);
                var1 = 0x0204;
                var3 = temp16;
                var2 = var3 + temp17;
                var1 = func_0632(var2, var3);
                var0 = var1;
            
                if (!var0) {
                label_02A3:
                    var temp18 = memory[0x40:0x60];
                    memory[temp18:temp18 + 0x20] = 0x70a08231 << 0xe0;
                    memory[temp18 + 0x04:temp18 + 0x04 + 0x20] = address(this);
                    var1 = 0x00;
                    var2 = 0xac531eb26ca1d21b85126de8fb87e80e09002dcf;
                    var3 = 0x70a08231;
                    var4 = temp18 + 0x24;
                    var temp19 = memory[0x40:0x60];
                    var temp20;
                    temp20, memory[temp19:temp19 + 0x20] = address(var2).staticcall.gas(msg.gas)(memory[temp19:temp19 + var4 - temp19]);
                    var5 = !temp20;
                
                    if (!var5) {
                        var temp21 = memory[0x40:0x60];
                        var temp22 = returndata.length;
                        memory[0x40:0x60] = temp21 + (temp22 + 0x1f & ~0x1f);
                        var2 = 0x0316;
                        var4 = temp21;
                        var3 = var4 + temp22;
                        var2 = func_0632(var3, var4);
                        var1 = var2;
                    
                        if (!var1) {
                        label_03C2:
                            return var0;
                        } else {
                            var temp23 = memory[0x40:0x60];
                            memory[temp23:temp23 + 0x20] = 0xa9059cbb << 0xe0;
                            memory[temp23 + 0x04:temp23 + 0x04 + 0x20] = 0x00000000000000000000000067624bfadee937c9281b4f98ce18af1bee01257e & (0x01 << 0xa0) - 0x01;
                            memory[temp23 + 0x24:temp23 + 0x24 + 0x20] = var1;
                            var2 = 0xac531eb26ca1d21b85126de8fb87e80e09002dcf;
                            var3 = 0xa9059cbb;
                            var4 = temp23 + 0x44;
                            var temp24 = memory[0x40:0x60];
                            var temp25;
                            temp25, memory[temp24:temp24 + 0x20] = address(var2).call.gas(msg.gas)(memory[temp24:temp24 + var4 - temp24]);
                            var5 = !temp25;
                        
                            if (!var5) {
                                var temp26 = memory[0x40:0x60];
                                var temp27 = returndata.length;
                                memory[0x40:0x60] = temp26 + (temp27 + 0x1f & ~0x1f);
                                var2 = 0x03c0;
                                var4 = temp26;
                                var3 = var4 + temp27;
                                var2 = func_0649(var3, var4);
                                goto label_03C2;
                            } else {
                                var temp28 = returndata.length;
                                memory[0x00:0x00 + temp28] = returndata[0x00:0x00 + temp28];
                                revert(memory[0x00:0x00 + returndata.length]);
                            }
                        }
                    } else {
                        var temp29 = returndata.length;
                        memory[0x00:0x00 + temp29] = returndata[0x00:0x00 + temp29];
                        revert(memory[0x00:0x00 + returndata.length]);
                    }
                } else {
                    var temp30 = memory[0x40:0x60];
                    memory[temp30:temp30 + 0x20] = 0xa9059cbb << 0xe0;
                    memory[temp30 + 0x04:temp30 + 0x04 + 0x20] = 0x00000000000000000000000067624bfadee937c9281b4f98ce18af1bee01257e & (0x01 << 0xa0) - 0x01;
                    memory[temp30 + 0x24:temp30 + 0x24 + 0x20] = var0;
                    var1 = (0x21 << 0x99) + 0x06;
                    var2 = 0xa9059cbb;
                    var3 = temp30 + 0x44;
                    var temp31 = memory[0x40:0x60];
                    var temp32;
                    temp32, memory[temp31:temp31 + 0x20] = address(var1).call.gas(msg.gas)(memory[temp31:temp31 + var3 - temp31]);
                    var4 = !temp32;
                
                    if (!var4) {
                        var temp33 = memory[0x40:0x60];
                        var temp34 = returndata.length;
                        memory[0x40:0x60] = temp33 + (temp34 + 0x1f & ~0x1f);
                        var1 = 0x02a1;
                        var2 = temp33 + temp34;
                        var3 = temp33;
                        var1 = func_0649(var2, var3);
                        goto label_02A3;
                    } else {
                        var temp35 = returndata.length;
                        memory[0x00:0x00 + temp35] = returndata[0x00:0x00 + temp35];
                        revert(memory[0x00:0x00 + returndata.length]);
                    }
                }
            } else {
                var temp36 = returndata.length;
                memory[0x00:0x00 + temp36] = returndata[0x00:0x00 + temp36];
                revert(memory[0x00:0x00 + returndata.length]);
            }
        } else {
            var temp37 = returndata.length;
            memory[0x00:0x00 + temp37] = returndata[0x00:0x00 + temp37];
            revert(memory[0x00:0x00 + returndata.length]);
        }
    }
    
    function func_00F5(var arg0, var arg1, var arg2, var arg3) {
        if (arg1 i<= 0x00) {
        label_044D:
        
            if (arg0 i<= 0x00) {
            label_04C3:
                return;
            } else {
                var temp0 = memory[0x40:0x60];
                memory[temp0:temp0 + 0x20] = 0xa9059cbb << 0xe0;
                memory[temp0 + 0x04:temp0 + 0x04 + 0x20] = msg.sender;
                memory[temp0 + 0x24:temp0 + 0x24 + 0x20] = arg0;
                var var0 = (0x21 << 0x99) + 0x06;
                var var1 = 0xa9059cbb;
                var var2 = temp0 + 0x44;
                var temp1 = memory[0x40:0x60];
                var temp2;
                temp2, memory[temp1:temp1 + 0x20] = address(var0).call.gas(msg.gas)(memory[temp1:temp1 + var2 - temp1]);
                var var3 = !temp2;
            
                if (!var3) {
                    var temp3 = memory[0x40:0x60];
                    var temp4 = returndata.length;
                    memory[0x40:0x60] = temp3 + (temp4 + 0x1f & ~0x1f);
                    var0 = 0x04c1;
                    var2 = temp3;
                    var1 = var2 + temp4;
                    var0 = func_0649(var1, var2);
                    goto label_04C3;
                } else {
                    var temp5 = returndata.length;
                    memory[0x00:0x00 + temp5] = returndata[0x00:0x00 + temp5];
                    revert(memory[0x00:0x00 + returndata.length]);
                }
            }
        } else {
            var temp6 = memory[0x40:0x60];
            memory[temp6:temp6 + 0x20] = 0xa9059cbb << 0xe0;
            memory[temp6 + 0x04:temp6 + 0x04 + 0x20] = msg.sender;
            memory[temp6 + 0x24:temp6 + 0x24 + 0x20] = arg1;
            var0 = 0xac531eb26ca1d21b85126de8fb87e80e09002dcf;
            var1 = 0xa9059cbb;
            var2 = temp6 + 0x44;
            var temp7 = memory[0x40:0x60];
            var temp8;
            temp8, memory[temp7:temp7 + 0x20] = address(var0).call.gas(msg.gas)(memory[temp7:temp7 + var2 - temp7]);
            var3 = !temp8;
        
            if (!var3) {
                var temp9 = memory[0x40:0x60];
                var temp10 = returndata.length;
                memory[0x40:0x60] = temp9 + (temp10 + 0x1f & ~0x1f);
                var0 = 0x044b;
                var2 = temp9;
                var1 = var2 + temp10;
                var0 = func_0649(var1, var2);
                goto label_044D;
            } else {
                var temp11 = returndata.length;
                memory[0x00:0x00 + temp11] = returndata[0x00:0x00 + temp11];
                revert(memory[0x00:0x00 + returndata.length]);
            }
        }
    }
    
    function func_04C9(var arg0) {
        var temp0 = arg0;
    
        if (temp0 == temp0 & (0x01 << 0xa0) - 0x01) { return; }
        else { revert(memory[0x00:0x00]); }
    }
    
    function func_04E0(var arg0, var arg1) returns (var r0, var arg0, var arg1) {
        var var0 = 0x00;
        var var1 = var0;
        var var2 = 0x00;
    
        if (arg0 - arg1 i< 0x60) { revert(memory[0x00:0x00]); }
    
        var var3 = msg.data[arg1:arg1 + 0x20];
        var var4 = 0x04fd;
        var var5 = var3;
        func_04C9(var5);
        var0 = var3;
        var temp0 = arg1;
        var1 = msg.data[temp0 + 0x20:temp0 + 0x20 + 0x20];
        var3 = msg.data[temp0 + 0x40:temp0 + 0x40 + 0x20];
        var4 = 0x0514;
        var5 = var3;
        func_04C9(var5);
        arg1 = var3;
        arg0 = var1;
        r0 = var0;
        return r0, arg0, arg1;
    }
    
    function func_051F(var arg0, var arg1) returns (var r0, var arg0, var arg1, var r3) {
        r3 = 0x00;
        var var1 = r3;
        var var2 = 0x00;
        var var3 = var2;
    
        if (arg0 - arg1 i< 0x60) { revert(memory[0x00:0x00]); }
    
        var temp0 = arg1;
        r3 = msg.data[temp0:temp0 + 0x20];
        var1 = msg.data[temp0 + 0x20:temp0 + 0x20 + 0x20];
        var var4 = msg.data[temp0 + 0x40:temp0 + 0x40 + 0x20];
        var var5 = 0xffffffffffffffff;
    
        if (var4 > var5) { revert(memory[0x00:0x00]); }
    
        var temp1 = arg1 + var4;
        var4 = temp1;
    
        if (var4 + 0x1f i>= arg0) { revert(memory[0x00:0x00]); }
    
        var var6 = msg.data[var4:var4 + 0x20];
    
        if (var6 > var5) { revert(memory[0x00:0x00]); }
    
        if (var4 + var6 + 0x20 > arg0) { revert(memory[0x00:0x00]); }
    
        var temp2 = r3;
        r3 = var6;
        r0 = temp2;
        arg0 = var1;
        arg1 = var4 + 0x20;
        return r0, arg0, arg1, r3;
    }
    
    function func_0598(var arg0, var arg1, var arg2, var arg3, var arg4, var arg5) returns (var r0) {
        var var0 = 0x00;
        var temp0 = (0x01 << 0xa0) - 0x01;
        var temp1 = arg5;
        memory[temp1:temp1 + 0x20] = arg0 & temp0;
        var var2 = 0x20;
        memory[temp1 + 0x20:temp1 + 0x20 + 0x20] = !!arg1;
        memory[temp1 + 0x40:temp1 + 0x40 + 0x20] = arg2;
        memory[temp1 + 0x60:temp1 + 0x60 + 0x20] = arg3 & temp0;
        memory[temp1 + 0x80:temp1 + 0x80 + 0x20] = 0xa0;
        var temp2 = memory[arg4:arg4 + 0x20];
        var var1 = temp2;
        memory[temp1 + 0xa0:temp1 + 0xa0 + 0x20] = var1;
        var var3 = 0x00;
    
        if (var3 >= var1) {
        label_05EC:
            var temp3 = var1;
            var temp4 = arg5;
            memory[temp4 + temp3 + 0xc0:temp4 + temp3 + 0xc0 + 0x20] = 0x00;
            return temp4 + (temp3 + 0x1f & ~0x1f) + 0xc0;
        } else {
        label_05D9:
            var temp5 = var3;
            var temp6 = var2;
            memory[temp5 + arg5 + 0xc0:temp5 + arg5 + 0xc0 + 0x20] = memory[temp6 + temp5 + arg4:temp6 + temp5 + arg4 + 0x20];
            var3 = temp6 + temp5;
        
            if (var3 >= var1) { goto label_05EC; }
            else { goto label_05D9; }
        }
    }
    
    function func_0610(var arg0, var arg1) returns (var r0, var arg0) {
        var var0 = 0x00;
        var var1 = var0;
    
        if (arg0 - arg1 i< 0x40) { revert(memory[0x00:0x00]); }
    
        var temp0 = arg1;
        r0 = memory[temp0:temp0 + 0x20];
        arg0 = memory[temp0 + 0x20:temp0 + 0x20 + 0x20];
        return r0, arg0;
    }
    
    function func_0632(var arg0, var arg1) returns (var r0) {
        var var0 = 0x00;
    
        if (arg0 - arg1 i>= 0x20) { return memory[arg1:arg1 + 0x20]; }
        else { revert(memory[0x00:0x00]); }
    }
    
    function func_0649(var arg0, var arg1) returns (var r0) {
        var var0 = 0x00;
    
        if (arg0 - arg1 i< 0x20) { revert(memory[0x00:0x00]); }
    
        var temp0 = memory[arg1:arg1 + 0x20];
        var var1 = temp0;
    
        if (var1 == !!var1) { return var1; }
        else { revert(memory[0x00:0x00]); }
    }
}

