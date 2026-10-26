contract Contract {
    function main() {
        var var0 = 0x80;
        memory[0x40:0x60] = var0;
    
        if (msg.data.length < 0x04) { revert(memory[0x00:0x00]); }
    
        var var1 = var0;
        var0 = msg.data[0x00:0x20] >> 0xe0;
    
        if (var0 == 0x01e1d114) {
            // Dispatch table entry for totalAssets()
            if (msg.value) { revert(memory[0x00:0x00]); }
        
            if (msg.data.length + ~0x03 i< 0x00) { revert(memory[0x00:0x00]); }
        
            var temp0 = var1;
            memory[temp0:temp0 + 0x20] = 0x00;
            return memory[temp0:temp0 + 0x20];
        } else if (var0 == 0x06fdde03) {
            // Dispatch table entry for name()
            if (msg.value) { revert(memory[0x00:0x00]); }
        
            if (msg.data.length + ~0x03 i< 0x00) { revert(memory[0x00:0x00]); }
        
            var1 = 0x021a;
            var var2 = memory[0x40:0x60];
            var var3 = 0x086d;
            var var4 = 0x60;
            var var5 = var2;
            func_0953(var4, var5);
            var1, var2, var3 = func_086D(var2);
        
        label_021A:
            return memory[var1:var1 + var3 - var2];
        } else if (var0 == 0x07a2d13a) {
            // Dispatch table entry for convertToAssets(uint256)
            if (msg.value) { revert(memory[0x00:0x00]); }
        
            if (msg.data.length + ~0x03 i< 0x20) { revert(memory[0x00:0x00]); }
        
            var temp1 = memory[0x40:0x60];
            memory[temp1:temp1 + 0x20] = 0x00;
            return memory[temp1:temp1 + 0x20];
        } else if (var0 == 0x18160ddd) {
            // Dispatch table entry for totalSupply()
            if (msg.value) { revert(memory[0x00:0x00]); }
        
            if (msg.data.length + ~0x03 i< 0x00) { revert(memory[0x00:0x00]); }
        
            var temp2 = memory[0x40:0x60];
            memory[temp2:temp2 + 0x20] = storage[0x02];
            return memory[temp2:temp2 + 0x20];
        } else if (var0 == 0x313ce567) {
            // Dispatch table entry for decimals()
            if (msg.value) { revert(memory[0x00:0x00]); }
        
            if (msg.data.length + ~0x03 i< 0x00) { revert(memory[0x00:0x00]); }
        
            var temp3 = memory[0x40:0x60];
            memory[temp3:temp3 + 0x20] = 0x12;
            return memory[temp3:temp3 + 0x20];
        } else if (var0 == 0x38d52e0f) {
            // Dispatch table entry for asset()
            if (msg.value) { revert(memory[0x00:0x00]); }
        
            if (msg.data.length + ~0x03 i< 0x00) { revert(memory[0x00:0x00]); }
        
            var temp4 = memory[0x40:0x60];
            memory[temp4:temp4 + 0x20] = 0x000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2 & (0x01 << 0xa0) - 0x01;
            return memory[temp4:temp4 + 0x20];
        } else if (var0 == 0x402d267d) {
            // Dispatch table entry for maxDeposit(address)
            if (msg.value) { revert(memory[0x00:0x00]); }
        
            if (msg.data.length + ~0x03 i< 0x20) { revert(memory[0x00:0x00]); }
        
            var1 = 0x0750;
            var1 = maxRedeem();
            var temp5 = var1;
            var1 = !(storage[0x00] & 0xff);
            var2 = temp5;
        
            if (!var1) { goto label_075E; }
        
            var temp6 = (0x01 << 0xa0) - 0x01;
            var1 = var2 & temp6 == temp6 & 0x00000000000000000000000026fcb50eec367ddab060ccf5e7394cecd95f7db2;
            var2 = var0;
        
        label_075E:
        
            if (!var1) {
                var1 = 0x20;
                var2 = 0x00;
                var temp7 = memory[0x40:0x60];
                memory[temp7:temp7 + 0x20] = var2;
                return memory[temp7:temp7 + var1];
            } else {
                var temp8 = memory[0x40:0x60];
                memory[temp8:temp8 + 0x20] = ~0x00;
                return memory[temp8:temp8 + 0x20];
            }
        } else if (var0 == 0x63898e2b) {
            // Dispatch table entry for used()
            if (msg.value) { revert(memory[0x00:0x00]); }
        
            if (msg.data.length + ~0x03 i< 0x00) { revert(memory[0x00:0x00]); }
        
            var temp9 = memory[0x40:0x60];
            memory[temp9:temp9 + 0x20] = !!(storage[0x00] & 0xff);
            return memory[temp9:temp9 + 0x20];
        } else if (var0 == 0x66d003ac) {
            // Dispatch table entry for recipient()
            if (msg.value) { revert(memory[0x00:0x00]); }
        
            if (msg.data.length + ~0x03 i< 0x00) { revert(memory[0x00:0x00]); }
        
            var temp10 = memory[0x40:0x60];
            memory[temp10:temp10 + 0x20] = 0x000000000000000000000000a908b3472d76e7744bab0a5911768a4a6300612b & (0x01 << 0xa0) - 0x01;
            return memory[temp10:temp10 + 0x20];
        } else if (var0 == 0x69b41170) {
            // Dispatch table entry for DELAY()
            if (msg.value) { revert(memory[0x00:0x00]); }
        
            if (msg.data.length + ~0x03 i< 0x00) { revert(memory[0x00:0x00]); }
        
            var temp11 = memory[0x40:0x60];
            memory[temp11:temp11 + 0x20] = 0x35c99cf4a5df2d9bcd822bee32676d9590229e33;
            return memory[temp11:temp11 + 0x20];
        } else if (var0 == 0x6e553f65) {
            // Dispatch table entry for deposit(uint256,address)
            if (msg.value) { revert(memory[0x00:0x00]); }
        
            if (msg.data.length + ~0x03 i< 0x40) { revert(memory[0x00:0x00]); }
        
            var1 = msg.data[0x04:0x24];
            var2 = 0x0274;
            var2 = func_0927();
            var temp12 = var2;
            var2 = var1;
            var3 = temp12;
            var1 = 0x00000000000000000000000026fcb50eec367ddab060ccf5e7394cecd95f7db2 & (0x01 << 0xa0) - 0x01;
        
            if (msg.sender - var1) {
                memory[0x00:0x20] = 0x8d1af8bd << 0xe0;
                revert(memory[0x00:0x04]);
            } else {
                var temp13 = var3 & (0x01 << 0xa0) - 0x01;
                var temp14 = var1;
                var1 = temp13;
                var3 = temp14;
            
                if (var1 - var3) {
                    memory[0x00:0x20] = 0x1e4ec46b << 0xe0;
                    revert(memory[0x00:0x04]);
                } else {
                    var4 = storage[0x00];
                
                    if (var4 & 0xff) {
                        memory[0x00:0x20] = 0x07b8c821 << 0xe4;
                        revert(memory[0x00:0x04]);
                    } else if (!var2) {
                        memory[0x00:0x20] = 0x0cb65c77 << 0xe2;
                        revert(memory[0x00:0x04]);
                    } else {
                        var temp15 = memory[0x40:0x60];
                        memory[temp15:temp15 + 0x20] = 0xdcafac09 << 0xe0;
                        var temp16;
                        temp16, memory[temp15:temp15 + 0x20] = address(0x35c99cf4a5df2d9bcd822bee32676d9590229e33).staticcall.gas(msg.gas)(memory[temp15:temp15 + 0x04]);
                        var var6 = temp15;
                    
                        if (!temp16) {
                        label_05AB:
                            var temp17 = memory[0x40:0x60];
                            var temp18 = returndata.length;
                            memory[temp17:temp17 + temp18] = returndata[0x00:0x00 + temp18];
                            revert(memory[temp17:temp17 + returndata.length]);
                        } else {
                            var5 = 0x00;
                        
                            if (!var5) { goto label_0302; }
                        
                            var temp19 = var6;
                            var5 = temp19;
                            var6 = 0x20;
                            var var7 = var5;
                        
                            if (0x20 <= returndata.length) { goto label_0639; }
                        
                            var6 = returndata.length;
                        
                        label_0639:
                            var temp20 = var6;
                            var var8 = temp20;
                            var var9 = 0x0646;
                            var6 = 0x20;
                            var var10 = var8;
                            var var11 = var7;
                            func_0953(var10, var11);
                            var temp21 = var7;
                        
                            if ((temp21 + var8) - temp21 i< var6) { revert(memory[0x00:0x00]); }
                        
                            var5 = memory[var5:var5 + 0x20];
                            var6 = var0;
                        
                        label_0302:
                            var5 = !!var5;
                        
                            if (var5) { goto label_030C; }
                        
                            var temp22 = memory[0x40:0x60];
                            memory[temp22:temp22 + 0x20] = 0x18177d67 << 0xe2;
                            var temp23;
                            temp23, memory[temp22:temp22 + 0x20] = address(0x35c99cf4a5df2d9bcd822bee32676d9590229e33).staticcall.gas(msg.gas)(memory[temp22:temp22 + 0x04]);
                            var6 = temp22;
                        
                            if (!temp23) { goto label_05AB; }
                        
                            var5 = 0x00;
                        
                            if (!var5) { goto label_05F1; }
                        
                            var temp24 = var6;
                            var5 = temp24;
                            var6 = 0x20;
                            var7 = var5;
                        
                            if (0x20 <= returndata.length) { goto label_0607; }
                        
                            var6 = returndata.length;
                        
                        label_0607:
                            var temp25 = var6;
                            var8 = temp25;
                            var9 = 0x0614;
                            var6 = 0x20;
                            var10 = var8;
                            var11 = var7;
                            func_0953(var10, var11);
                            var temp26 = var7;
                        
                            if ((temp26 + var8) - temp26 i< var6) { revert(memory[0x00:0x00]); }
                        
                            var5 = memory[var5:var5 + 0x20];
                            var6 = var0;
                        
                        label_05F1:
                            var5 = !!var5;
                        
                        label_030C:
                        
                            if (var5) { goto label_0313; }
                        
                            var temp27 = memory[0x40:0x60];
                            memory[temp27:temp27 + 0x20] = 0x2d9ad53d << 0xe0;
                            memory[temp27 + 0x04:temp27 + 0x04 + 0x20] = 0x0ae12af3878a2d896f5c4dce3be7250fb187c0a6;
                            var temp28;
                            temp28, memory[temp27:temp27 + 0x20] = address(0x35c99cf4a5df2d9bcd822bee32676d9590229e33).staticcall.gas(msg.gas)(memory[temp27:temp27 + 0x24]);
                            var6 = temp27;
                        
                            if (!temp28) { goto label_05AB; }
                        
                            var5 = 0x00;
                        
                            if (!var5) { goto label_0562; }
                        
                            var7 = 0x20;
                            var8 = var6;
                        
                            if (0x20 <= returndata.length) { goto label_0575; }
                        
                            var7 = returndata.length;
                        
                        label_0575:
                            var temp29 = var7;
                            var9 = temp29;
                            var10 = 0x0582;
                            var7 = 0x20;
                            var11 = var9;
                            var var12 = var8;
                            func_0953(var11, var12);
                            var temp30 = var8;
                        
                            if ((temp30 + var9) - temp30 i< var7) {
                                var temp31 = var5;
                                revert(memory[temp31:temp31 + temp31]);
                            } else {
                                var temp32 = memory[var6:var6 + 0x20];
                                var6 = var5;
                                var5 = temp32;
                            
                                if (var5 - !!var5) {
                                    var temp33 = var6;
                                    revert(memory[temp33:temp33 + temp33]);
                                } else {
                                    var6 = var0;
                                
                                label_0562:
                                    var5 = !var5;
                                
                                label_0313:
                                
                                    if (var5) {
                                        memory[0x00:0x20] = 0xcb22780b << 0xe0;
                                        revert(memory[0x00:0x04]);
                                    } else {
                                        storage[0x00] = (var4 & ~0xff) | 0x01;
                                        var temp34 = var2;
                                        storage[0x01] = temp34;
                                        storage[0x02] = temp34;
                                        memory[0x00:0x20] = var1;
                                        memory[0x20:0x40] = 0x03;
                                        storage[keccak256(memory[0x00:0x40])] = temp34;
                                        var temp35 = var3;
                                        var3 = 0x000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2 & (0x01 << 0xa0) - 0x01;
                                        var4 = temp35;
                                        var5 = var1;
                                        var1 = memory[0x40:0x60];
                                        memory[0x00:0x20] = 0x23b872dd << 0xe0;
                                        memory[0x04:0x24] = var4;
                                        memory[0x24:0x44] = address(this);
                                        memory[0x44:0x64] = temp34;
                                        var temp36;
                                        temp36, memory[0x00:0x20] = address(var3).call.gas(msg.gas)(memory[0x00:0x64]);
                                    
                                        if (temp36 & (memory[0x00:0x20] == 0x01)) { goto label_0399; }
                                    
                                        if (!var6 & 0x01) {
                                            var temp37 = var1;
                                            var temp38 = returndata.length;
                                            memory[temp37:temp37 + temp38] = returndata[0x00:0x00 + temp38];
                                            revert(memory[temp37:temp37 + returndata.length]);
                                        } else {
                                            var6 = !returndata.length & !!address(var3).code.length & var6;
                                        
                                        label_0399:
                                            memory[0x40:0x60] = var1;
                                            memory[0x60:0x80] = 0x00;
                                        
                                            if (!var6) {
                                                memory[0x00:0x20] = 0x5274afe7 << 0xe0;
                                                memory[0x04:0x24] = var3;
                                                revert(memory[0x00:0x24]);
                                            } else {
                                                var temp39 = var3;
                                                var6 = temp39;
                                                memory[0x00:0x20] = 0xa9059cbb << 0xe0;
                                                var3 = 0x000000000000000000000000a908b3472d76e7744bab0a5911768a4a6300612b & (0x01 << 0xa0) - 0x01;
                                                memory[0x04:0x24] = var3;
                                                memory[0x24:0x44] = var2;
                                                var temp40;
                                                temp40, memory[0x00:0x20] = address(var6).call.gas(msg.gas)(memory[0x00:0x44]);
                                            
                                                if (temp40 & (memory[0x00:0x20] == 0x01)) { goto label_03FE; }
                                            
                                                if (!var7 & 0x01) {
                                                    var temp41 = var1;
                                                    var temp42 = returndata.length;
                                                    memory[temp41:temp41 + temp42] = returndata[0x00:0x00 + temp42];
                                                    revert(memory[temp41:temp41 + returndata.length]);
                                                } else {
                                                    var7 = !returndata.length & !!address(var6).code.length & var7;
                                                
                                                label_03FE:
                                                    memory[0x40:0x60] = var1;
                                                
                                                    if (!var7) {
                                                        memory[0x00:0x20] = 0x5274afe7 << 0xe0;
                                                        memory[0x04:0x24] = var6;
                                                        revert(memory[0x00:0x24]);
                                                    } else {
                                                        var temp43 = var5;
                                                        var temp44 = var1;
                                                        var temp45 = var2;
                                                        memory[temp44:temp44 + 0x20] = temp45;
                                                        log(memory[temp44:temp44 + 0x20], [0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef, 0x00, stack[-2]]);
                                                        var temp46 = var4;
                                                        var temp47 = memory[0x40:0x60];
                                                        memory[temp47:temp47 + 0x20] = temp45;
                                                        memory[temp47 + 0x20:temp47 + 0x20 + 0x20] = temp45;
                                                        log(memory[temp47:temp47 + 0x40], [0xdcbc1c05240f31ff3ad067ef1ee35ce4997762752e3a095284754544f4c709d7, stack[-3], stack[-2]]);
                                                        var temp48 = memory[0x40:0x60];
                                                        memory[temp48:temp48 + 0x20] = temp45;
                                                        log(memory[temp48:temp48 + 0x20], [0x2aefe94e9f22ace9635204ccf0eafa36414786bbe73cd101dd685e7e3243ac22, stack[-3], stack[-4]]);
                                                        var temp49 = memory[0x40:0x60];
                                                        memory[temp49:temp49 + 0x20] = temp45;
                                                        return memory[temp49:temp49 + 0x20];
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        } else if (var0 == 0x70a08231) {
            // Dispatch table entry for balanceOf(address)
            if (msg.value) { revert(memory[0x00:0x00]); }
        
            if (msg.data.length + ~0x03 i< 0x20) { revert(memory[0x00:0x00]); }
        
            var1 = (0x01 << 0xa0) - 0x01;
            var2 = 0x023f;
            var2 = maxRedeem();
            memory[0x00:0x20] = var2 & var1;
            memory[0x20:0x40] = 0x03;
            var temp50 = memory[0x40:0x60];
            memory[temp50:temp50 + 0x20] = storage[keccak256(memory[0x00:0x40])];
            return memory[temp50:temp50 + 0x20];
        } else if (var0 == 0x95d89b41) {
            // Dispatch table entry for symbol()
            if (msg.value) { revert(memory[0x00:0x00]); }
        
            if (msg.data.length + ~0x03 i< 0x00) { revert(memory[0x00:0x00]); }
        
            var1 = 0x021a;
            var2 = memory[0x40:0x60];
            var3 = 0x01f6;
            var4 = 0x40;
            var5 = var2;
            func_0953(var4, var5);
            var1, var2, var3 = func_01F6(var2);
            goto label_021A;
        } else if (var0 == 0x95f8492c) {
            // Dispatch table entry for 0x95f8492c (unknown)
            if (msg.value) { revert(memory[0x00:0x00]); }
        
            if (msg.data.length + ~0x03 i< 0x00) { revert(memory[0x00:0x00]); }
        
            var temp51 = memory[0x40:0x60];
            memory[temp51:temp51 + 0x20] = storage[0x01];
            return memory[temp51:temp51 + 0x20];
        } else if (var0 == 0x98fabd3a) {
            // Dispatch table entry for DAO()
            if (msg.value) { revert(memory[0x00:0x00]); }
        
            if (msg.data.length + ~0x03 i< 0x00) { revert(memory[0x00:0x00]); }
        
            var temp52 = memory[0x40:0x60];
            memory[temp52:temp52 + 0x20] = 0x0ae12af3878a2d896f5c4dce3be7250fb187c0a6;
            return memory[temp52:temp52 + 0x20];
        } else if (var0 == 0xba087652) {
            // Dispatch table entry for redeem(uint256,address,address)
            if (msg.value) { revert(memory[0x00:0x00]); }
        
            if (msg.data.length + ~0x03 i< 0x60) { revert(memory[0x00:0x00]); }
        
            var1 = 0x016c;
            var1 = func_0927();
            var1 = 0x0175;
            var1 = func_093D();
            memory[0x00:0x20] = 0x783cdf7f << 0xe1;
            revert(memory[0x00:0x04]);
        } else if (var0 == 0xd905777e) {
            // Dispatch table entry for maxRedeem(address)
            if (msg.value) { revert(memory[0x00:0x00]); }
        
            if (msg.data.length + ~0x03 i< 0x20) { revert(memory[0x00:0x00]); }
        
            var1 = 0x0147;
            var1 = maxRedeem();
            var temp53 = memory[0x40:0x60];
            memory[temp53:temp53 + 0x20] = 0x00;
            return memory[temp53:temp53 + 0x20];
        } else if (var0 == 0xfbfa77cf) {
            // Dispatch table entry for vault()
            if (msg.value) { revert(memory[0x00:0x00]); }
        
            if (msg.data.length + ~0x03 i< 0x00) { revert(memory[0x00:0x00]); }
        
            var temp54 = memory[0x40:0x60];
            memory[temp54:temp54 + 0x20] = 0x00000000000000000000000026fcb50eec367ddab060ccf5e7394cecd95f7db2 & (0x01 << 0xa0) - 0x01;
            return memory[temp54:temp54 + 0x20];
        } else { revert(memory[0x00:0x00]); }
    }
    
    function func_01F6(var arg0) returns (var r0, var arg0, var r2) {
        var temp0 = arg0;
        memory[temp0:temp0 + 0x20] = 0x0b;
        memory[temp0 + 0x20:temp0 + 0x20 + 0x20] = 0x199c95d155120b51561255 << 0xaa;
        r2 = r0;
        r0 = memory[0x40:0x60];
        var var1 = temp0;
        arg0 = r0;
        var var2 = arg0;
        var temp1 = var2;
        var temp2 = var1;
        var1 = r2;
        var2 = temp1;
        r2 = temp2;
        memory[var2:var2 + 0x20] = 0x20;
        var temp3 = memory[r2:r2 + 0x20];
        var var3 = temp3;
        memory[var2 + 0x20:var2 + 0x20 + 0x20] = var3;
        var var4 = 0x00;
    
        if (var4 >= var3) { goto label_08E2; }
    
    label_08FB:
        var temp4 = var4;
        memory[var2 + temp4 + 0x40:var2 + temp4 + 0x40 + 0x20] = memory[r2 + temp4 + 0x20:r2 + temp4 + 0x20 + 0x20];
        var4 = temp4 + 0x20;
    
        if (var4 < var3) { goto label_08FB; }
    
    label_08E2:
        var temp5 = var3;
        var temp6 = var2;
        memory[temp6 + temp5 + 0x40:temp6 + temp5 + 0x40 + 0x20] = 0x00;
        r2 = (temp5 + 0x1f & ~0x1f) + temp6 + 0x40;
        return r0, arg0, r2;
    }
    
    function func_086D(var arg0) returns (var r0, var arg0, var r2) {
        var temp0 = arg0;
        memory[temp0:temp0 + 0x20] = 0x22;
        memory[temp0 + 0x20:temp0 + 0x20 + 0x20] = 0x466978656420526563697069656e742057455448204578697420537472617465;
        memory[temp0 + 0x40:temp0 + 0x40 + 0x20] = 0x6779 << 0xf0;
        var temp1 = r0;
        r0 = memory[0x40:0x60];
        r2 = temp1;
        var var1 = temp0;
        arg0 = r0;
        var var2 = arg0;
        var temp2 = var2;
        var temp3 = var1;
        var1 = r2;
        var2 = temp2;
        r2 = temp3;
        memory[var2:var2 + 0x20] = 0x20;
        var temp4 = memory[r2:r2 + 0x20];
        var var3 = temp4;
        memory[var2 + 0x20:var2 + 0x20 + 0x20] = var3;
        var var4 = 0x00;
    
        if (var4 >= var3) { goto label_08E2; }
    
    label_08FB:
        var temp5 = var4;
        memory[var2 + temp5 + 0x40:var2 + temp5 + 0x40 + 0x20] = memory[r2 + temp5 + 0x20:r2 + temp5 + 0x20 + 0x20];
        var4 = temp5 + 0x20;
    
        if (var4 < var3) { goto label_08FB; }
    
    label_08E2:
        var temp6 = var3;
        var temp7 = var2;
        memory[temp7 + temp6 + 0x40:temp7 + temp6 + 0x40 + 0x20] = 0x00;
        r2 = (temp6 + 0x1f & ~0x1f) + temp7 + 0x40;
        return r0, arg0, r2;
    }
    
    function maxRedeem() returns (var r0) {
        var temp0 = msg.data[0x04:0x24];
        var var0 = r0;
        r0 = temp0;
    
        if (r0 - (r0 & (0x01 << 0xa0) - 0x01)) { revert(memory[0x00:0x00]); }
        else { return r0; }
    }
    
    function func_0927() returns (var r0) {
        var temp0 = msg.data[0x24:0x44];
        var var0 = r0;
        r0 = temp0;
    
        if (r0 - (r0 & (0x01 << 0xa0) - 0x01)) { revert(memory[0x00:0x00]); }
        else { return r0; }
    }
    
    function func_093D() returns (var r0) {
        var temp0 = msg.data[0x44:0x64];
        var var0 = r0;
        r0 = temp0;
    
        if (r0 - (r0 & (0x01 << 0xa0) - 0x01)) { revert(memory[0x00:0x00]); }
        else { return r0; }
    }
    
    function func_0953(var arg0, var arg1) {
        var temp0 = arg1;
        var temp1 = temp0 + (arg0 + 0x1f & ~0x1f);
        arg0 = temp1;
    
        if ((arg0 > 0xffffffffffffffff) | (arg0 < temp0)) {
            memory[0x00:0x20] = 0x4e487b71 << 0xe0;
            memory[0x04:0x24] = 0x41;
            revert(memory[0x00:0x24]);
        } else {
            memory[0x40:0x60] = arg0;
            return;
        }
    }
}

