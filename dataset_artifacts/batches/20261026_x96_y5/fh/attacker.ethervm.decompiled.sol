contract Contract {
    function main() {
        var var0 = 0x80;
        memory[0x40:0x60] = var0;
    
        if (msg.data.length < 0x04) { goto label_000F; }
    
        var var1 = var0;
        var0 = msg.data[0x00:0x20] >> 0xe0;
    
        if (var0 == 0x05dd47d7) {
            // Dispatch table entry for 0x05dd47d7 (unknown)
            if (msg.value) { revert(memory[0x00:0x00]); }
        
            if (msg.data.length + ~0x03 i< 0x00) { revert(memory[0x00:0x00]); }
        
            var temp0 = var1;
            memory[temp0:temp0 + 0x20] = 0x10ed43c718714eb63d5aa57b78b54704e256024e;
            return memory[temp0:temp0 + 0x20];
        } else if (var0 == 0x13a1a562) {
            // Dispatch table entry for 0x13a1a562 (unknown)
            if (msg.value) { revert(memory[0x00:0x00]); }
        
            if (msg.data.length + ~0x03 i< 0x40) { revert(memory[0x00:0x00]); }
        
            var1 = msg.data[0x24:0x44];
        
            if (var1 > 0xffffffffffffffff) { revert(memory[0x00:0x00]); }
        
            if (var1 + 0x23 i>= msg.data.length) { revert(memory[0x00:0x00]); }
        
            var var2 = msg.data[var1 + 0x04:var1 + 0x04 + 0x20];
        
            if (var2 > 0xffffffffffffffff) { revert(memory[0x00:0x00]); }
        
            var temp1 = var1 + var2;
            var2 = temp1;
        
            if (var2 + 0x24 > msg.data.length) { revert(memory[0x00:0x00]); }
        
            if (msg.sender - 0x8f73b65b4caaf64fba2af91cc5d4a2a1318e5d8c) {
                var temp2 = memory[0x40:0x60];
                memory[temp2:temp2 + 0x20] = 0x461bcd << 0xe5;
                memory[temp2 + 0x04:temp2 + 0x04 + 0x20] = 0x20;
                memory[temp2 + 0x24:temp2 + 0x24 + 0x20] = 0x0a;
                memory[temp2 + 0x44:temp2 + 0x44 + 0x20] = 0x0dcdee840dadeded8c2d << 0xb3;
                revert(memory[temp2:temp2 + 0x64]);
            } else if (var2 - var1 i< 0xa0) { revert(memory[0x00:0x00]); }
            else {
                var2 = 0x066b;
                var var3 = var1 + 0x24;
                var2 = func_0CE4(var3);
                var3 = 0x0677;
                var var4 = var1 + 0x44;
                var3 = func_0CE4(var4);
                var temp3 = var3;
                var temp4 = var1;
                var3 = temp4;
                var1 = temp3;
                var4 = 0x0684;
                var var5 = var3 + 0x64;
                var4 = func_0CE4(var5);
                var temp5 = memory[0x40:0x60];
                memory[temp5:temp5 + 0x20] = 0x095ea7b3 << 0xe0;
                memory[temp5 + 0x04:temp5 + 0x04 + 0x20] = 0x10ed43c718714eb63d5aa57b78b54704e256024e;
                memory[temp5 + 0x24:temp5 + 0x24 + 0x20] = ~0x00;
                var temp6 = (0x01 << 0xa0) - 0x01;
                var temp7 = temp6 & var4;
                var temp8 = var1;
                var1 = temp7;
                var temp9 = var2;
                var2 = temp6 & temp8;
                var temp10 = var3;
                var3 = msg.data[temp10 + 0x84:temp10 + 0x84 + 0x20];
                var4 = msg.data[temp10 + 0xa4:temp10 + 0xa4 + 0x20];
                var var6 = temp5;
                var5 = temp6 & temp9;
                var temp11;
                temp11, memory[var6:var6 + 0x20] = address(var1).call.gas(msg.gas)(memory[var6:var6 + 0x44]);
            
                if (!temp11) {
                label_01A1:
                    var temp12 = memory[0x40:0x60];
                    var temp13 = returndata.length;
                    memory[temp12:temp12 + temp13] = returndata[0x00:0x00 + temp13];
                    revert(memory[temp12:temp12 + returndata.length]);
                } else {
                    // Error: StackRead before write???
                    var var7;
                
                    if (!var7) { goto label_06E3; }
                
                    var7 = var6;
                    var6 = 0x0c55;
                    var var8 = 0x20;
                
                    if (0x20 > returndata.length) {
                        var6 = func_019A(var7, var8);
                    
                    label_06E3:
                        var temp14 = memory[0x40:0x60];
                        var6 = temp14;
                        memory[var6:var6 + 0x20] = 0x095ea7b3 << 0xe0;
                        memory[var6 + 0x04:var6 + 0x04 + 0x20] = 0x10ed43c718714eb63d5aa57b78b54704e256024e;
                        memory[var6 + 0x24:var6 + 0x24 + 0x20] = ~0x00;
                        var temp15;
                        temp15, memory[var6:var6 + 0x20] = address(var5).call.gas(msg.gas)(memory[var6:var6 + 0x44]);
                    
                        if (!temp15) { goto label_01A1; }
                    
                        if (!var7) { goto label_0727; }
                    
                        var7 = var6;
                        var6 = 0x0c38;
                        var8 = 0x20;
                    
                        if (0x20 > returndata.length) {
                            var6 = func_019A(var7, var8);
                        
                        label_0727:
                            var temp16 = memory[0x40:0x60];
                            var6 = temp16;
                            memory[var6:var6 + 0x20] = 0x0dfe1681 << 0xe0;
                            var temp17;
                            temp17, memory[var6:var6 + 0x20] = address(var2).staticcall.gas(msg.gas)(memory[var6:var6 + 0x04]);
                        
                            if (!temp17) { goto label_01A1; }
                        
                            var8 = var6;
                            var6 = var1;
                            var7 = 0x00;
                        
                            if (!var7) { goto label_074D; }
                        
                            var6 = var8;
                            var7 = 0x20;
                            var8 = var6;
                        
                            if (0x20 <= returndata.length) { goto label_0BEA; }
                        
                            var7 = returndata.length;
                        
                        label_0BEA:
                            var temp18 = var7;
                            var var9 = temp18;
                            var var10 = 0x0bf7;
                            var7 = 0x20;
                            var var11 = var9;
                            var var12 = var8;
                            func_0CF8(var11, var12);
                            var temp19 = var8;
                        
                            if ((temp19 + var9) - temp19 i< var7) { revert(memory[0x00:0x00]); }
                        
                            var temp20 = memory[var6:var6 + 0x20];
                            var6 = temp20;
                        
                            if (var6 - (var6 & (0x01 << 0xa0) - 0x01)) { revert(memory[0x00:0x00]); }
                        
                            var7 = var6;
                            var6 = var1;
                            var8 = var0;
                        
                        label_074D:
                            var temp21 = var2;
                            var2 = 0x60;
                            var temp22 = var4;
                            var temp23 = var3;
                            var3 = temp22;
                            var4 = 0x40;
                            var temp24 = var6;
                            var6 = temp23;
                            var7 = temp24 == var7 & (0x01 << 0xa0) - 0x01;
                            var8 = temp21;
                            var9 = 0x00;
                        
                            if (var9 >= var3) { goto label_0772; }
                        
                        label_07C1:
                            var temp25 = memory[0x40:0x60];
                            var10 = temp25;
                            memory[var10:var10 + 0x20] = 0x0240bc6b << 0xe2;
                            var temp26;
                            temp26, memory[var10:var10 + var2] = address(var8).staticcall.gas(msg.gas)(memory[var10:var10 + 0x04]);
                        
                            if (!temp26) { goto label_01A1; }
                        
                            var11 = 0x00;
                            var12 = 0x00;
                        
                            if (!var11) { goto label_07E5; }
                        
                            var11 = var2;
                            var12 = var10;
                            var var13 = var11;
                        
                            if (var13 <= returndata.length) { goto label_0B8C; }
                        
                            var13 = returndata.length;
                        
                        label_0B8C:
                            var var14 = 0x0b96;
                            var var15 = var13;
                            var var16 = var12;
                            func_0CF8(var15, var16);
                            var temp27 = var12;
                        
                            if ((temp27 + var13) - temp27 i< var11) { revert(memory[0x00:0x00]); }
                        
                            var11 = 0x0ba7;
                            var12 = var10;
                            var11 = func_0D46(var12);
                            var temp28 = var10;
                            var10 = var11;
                            var11 = temp28;
                            var12 = 0x40;
                            var13 = 0x0bb6;
                            var14 = var11 + 0x20;
                            var13 = func_0D46(var14);
                            var temp29 = var11;
                            var11 = var13;
                            var temp30 = memory[temp29 + var12:temp29 + var12 + 0x20];
                        
                            if ((temp30 & 0xffffffff) - temp30) { revert(memory[0x00:0x00]); }
                        
                            var temp31 = var10;
                            var10 = (0x01 << 0x70) - 0x01;
                            var12 = var11;
                            var11 = temp31;
                        
                        label_07E5:
                            var10 = (0x01 << 0x70) - 0x01;
                        
                            if (!var7) {
                                var11 = var12;
                                var temp32 = var11 & var10;
                                var temp33 = var6;
                                var10 = temp32 * temp33;
                            
                                if (!(!temp32 | (temp33 == var10 / temp32))) {
                                label_04E3:
                                    memory[0x00:0x20] = 0x4e487b71 << 0xe0;
                                    memory[0x04:0x24] = 0x11;
                                    revert(memory[0x00:0x24]);
                                } else {
                                label_080A:
                                    var temp34 = memory[0x40:0x60];
                                    memory[temp34:temp34 + 0x20] = 0x70a08231 << 0xe0;
                                    memory[temp34 + 0x04:temp34 + 0x04 + 0x20] = address(this);
                                    var10 = var10 / 0x2710;
                                    var temp35;
                                    temp35, memory[temp34:temp34 + 0x20] = address(var1).staticcall.gas(msg.gas)(memory[temp34:temp34 + 0x24]);
                                    var12 = temp34;
                                
                                    if (!temp35) { goto label_01A1; }
                                
                                    var11 = 0x00;
                                
                                    if (!var11) { goto label_083A; }
                                
                                    var temp36 = var12;
                                    var11 = temp36;
                                    var12 = 0x20;
                                    var13 = var11;
                                
                                    if (var12 <= returndata.length) { goto label_0B54; }
                                
                                    var12 = returndata.length;
                                
                                label_0B54:
                                    var temp37 = var12;
                                    var14 = temp37;
                                    var15 = 0x0b61;
                                    var12 = 0x20;
                                    var16 = var14;
                                    var var17 = var13;
                                    func_0CF8(var16, var17);
                                    var temp38 = var13;
                                
                                    if ((temp38 + var14) - temp38 i< var12) { revert(memory[0x00:0x00]); }
                                
                                    var11 = memory[var11:var11 + 0x20];
                                    var12 = var0;
                                
                                label_083A:
                                
                                    if (var10 <= var11) { goto label_0843; }
                                
                                    var10 = var11;
                                    var11 = var0;
                                
                                label_0843:
                                
                                    if (!var10) {
                                    label_0772:
                                        var temp39 = var1;
                                        var temp40 = memory[0x40:0x60];
                                        var1 = temp40;
                                        memory[var1:var1 + 0x20] = 0x095ea7b3 << 0xe0;
                                        memory[var1 + 0x04:var1 + 0x04 + 0x20] = 0x8f73b65b4caaf64fba2af91cc5d4a2a1318e5d8c;
                                        memory[var1 + 0x24:var1 + 0x24 + 0x20] = msg.data[0x04:0x24];
                                        var temp41;
                                        temp41, memory[var1:var1 + 0x20] = address(temp39).call.gas(msg.gas)(memory[var1:var1 + 0x44]);
                                    
                                        if (!temp41) { goto label_01A1; }
                                    
                                        if (!var2) { stop(); }
                                    
                                    label_0179:
                                        var2 = var1;
                                        var1 = 0x001a;
                                        var3 = 0x20;
                                    
                                        if (0x20 > returndata.length) {
                                            var1 = func_019A(var2, var3);
                                            stop();
                                        } else {
                                            var4 = 0x0192;
                                            var5 = var3;
                                            var6 = var2;
                                            func_0CF8(var5, var6);
                                        
                                        label_0192:
                                            var temp42 = var2;
                                            var2 = temp42 + var3;
                                            var3 = temp42;
                                            var temp43 = var2;
                                            var2 = var3;
                                        
                                            if (temp43 - var2 i< 0x20) { revert(memory[0x00:0x00]); }
                                        
                                            var temp44 = memory[var2:var2 + 0x20];
                                            var2 = temp44;
                                        
                                            if (var2 - !!var2) { revert(memory[0x00:0x00]); }
                                        
                                            var1 = var2;
                                            // Error: Could not resolve jump destination!
                                        }
                                    } else {
                                        var11 = var10;
                                        var10 = memory[0x40:0x60];
                                        var12 = 0x0858;
                                        var13 = var2;
                                        var14 = var10;
                                        func_0CF8(var13, var14);
                                        var temp45 = var10;
                                        memory[temp45:temp45 + 0x20] = 0x02;
                                        var temp46 = var11;
                                        var11 = temp45 + 0x20;
                                        var12 = temp46;
                                        var temp47 = var4;
                                        memory[var11:var11 + temp47] = msg.data[msg.data.length:msg.data.length + temp47];
                                        var13 = var1;
                                        var14 = 0x086f;
                                        var15 = temp45;
                                        var14 = func_0D5A(var15);
                                        memory[var14:var14 + 0x20] = var13;
                                        var13 = var5;
                                        var14 = 0x087a;
                                        var15 = var10;
                                        var14 = func_0D7B(var15);
                                        memory[var14:var14 + 0x20] = var13;
                                    
                                        if (!address(0x10ed43c718714eb63d5aa57b78b54704e256024e).code.length) { revert(memory[0x00:0x00]); }
                                    
                                        var temp48 = var10;
                                        var temp49 = var11;
                                        var temp50 = memory[0x40:0x60];
                                        var10 = temp50;
                                        var11 = var10;
                                        memory[var11:var11 + 0x20] = 0x5c11d795 << 0xe0;
                                        memory[var11 + 0x04:var11 + 0x04 + 0x20] = var12;
                                        memory[var11 + 0x24:var11 + 0x24 + 0x20] = 0x00;
                                        memory[var11 + 0x44:var11 + 0x44 + 0x20] = 0xa0;
                                        var temp51 = memory[temp48:temp48 + 0x20];
                                        memory[var11 + 0xa4:var11 + 0xa4 + 0x20] = temp51;
                                        var12 = var11 + 0xc4;
                                        var13 = temp49;
                                        var15 = temp51;
                                        var14 = 0x00;
                                    
                                        if (var14 >= var15) { goto label_08D4; }
                                    
                                    label_0B14:
                                        var temp52 = var13;
                                        var temp53 = var12;
                                        memory[temp53:temp53 + 0x20] = memory[temp52:temp52 + 0x20] & (0x01 << 0xa0) - 0x01;
                                        var11 = var10;
                                        var12 = temp53 + 0x20;
                                        var13 = temp52 + 0x20;
                                        var14 = var14 + 0x01;
                                        var15 = var15;
                                    
                                        if (var14 < var15) { goto label_0B14; }
                                    
                                    label_08D4:
                                        var temp54 = var11;
                                        memory[temp54 + 0x64:temp54 + 0x64 + 0x20] = 0x1b81d678ffb9c0263b24a97847620c99d213eb14;
                                        memory[temp54 + 0x84:temp54 + 0x84 + 0x20] = block.timestamp;
                                        var temp55;
                                        temp55, memory[temp54:temp54 + 0x00] = address(0x10ed43c718714eb63d5aa57b78b54704e256024e).call.gas(msg.gas)(memory[temp54:temp54 + var12 - temp54]);
                                    
                                        if (!temp55) { goto label_01A1; }
                                    
                                        if (!var11) { goto label_0920; }
                                    
                                        var11 = 0x00;
                                        var12 = var10;
                                        var10 = 0x0b0e;
                                        func_0CF8(var11, var12);
                                        var10 = var0;
                                    
                                    label_0920:
                                    
                                        if (!address(0x1b81d678ffb9c0263b24a97847620c99d213eb14).code.length) { revert(memory[0x00:0x00]); }
                                    
                                        var temp56 = memory[0x40:0x60];
                                        var10 = temp56;
                                        memory[var10:var10 + 0x20] = 0xdf2ab5bb << 0xe0;
                                        memory[var10 + 0x04:var10 + 0x04 + 0x20] = var5;
                                        memory[var10 + 0x24:var10 + 0x24 + 0x20] = 0x00;
                                        memory[var10 + 0x44:var10 + 0x44 + 0x20] = address(this);
                                        var temp57;
                                        temp57, memory[var10:var10 + 0x00] = address(0x1b81d678ffb9c0263b24a97847620c99d213eb14).call.gas(msg.gas)(memory[var10:var10 + 0x64]);
                                    
                                        if (!temp57) { goto label_01A1; }
                                    
                                        if (!var11) { goto label_0983; }
                                    
                                        var11 = 0x00;
                                        var12 = var10;
                                        var10 = 0x0afe;
                                        func_0CF8(var11, var12);
                                        var10 = var0;
                                    
                                    label_0983:
                                        var temp58 = memory[0x40:0x60];
                                        memory[temp58:temp58 + 0x20] = 0x70a08231 << 0xe0;
                                        memory[temp58 + 0x04:temp58 + 0x04 + 0x20] = address(this);
                                        var10 = var9;
                                        var temp59;
                                        temp59, memory[temp58:temp58 + 0x20] = address(var5).staticcall.gas(msg.gas)(memory[temp58:temp58 + 0x24]);
                                        var11 = temp58;
                                    
                                        if (!temp59) { goto label_01A1; }
                                    
                                        var9 = 0x00;
                                    
                                        if (!var9) { goto label_09AF; }
                                    
                                        var temp60 = var10;
                                        var temp61 = var11;
                                        var10 = temp61;
                                        var9 = temp60;
                                        var11 = 0x20;
                                        var12 = var10;
                                    
                                        if (var11 <= returndata.length) { goto label_0ACF; }
                                    
                                        var11 = returndata.length;
                                    
                                    label_0ACF:
                                        var temp62 = var11;
                                        var13 = temp62;
                                        var14 = 0x0adc;
                                        var11 = 0x20;
                                        var15 = var13;
                                        var16 = var12;
                                        func_0CF8(var15, var16);
                                        var temp63 = var12;
                                    
                                        if ((temp63 + var13) - temp63 i< var11) { revert(memory[0x00:0x00]); }
                                    
                                        var temp64 = var9;
                                        var9 = memory[var10:var10 + 0x20];
                                        var10 = temp64;
                                        var11 = var0;
                                    
                                    label_09AF:
                                    
                                        if (!var9) { goto label_09B6; }
                                    
                                        var temp65 = var9;
                                        var9 = memory[0x40:0x60];
                                        var11 = temp65;
                                        var12 = 0x09ce;
                                        var13 = var2;
                                        var14 = var9;
                                        func_0CF8(var13, var14);
                                        var temp66 = var9;
                                        memory[temp66:temp66 + 0x20] = 0x02;
                                        var12 = var11;
                                        var11 = temp66 + 0x20;
                                        var temp67 = var4;
                                        memory[var11:var11 + temp67] = msg.data[msg.data.length:msg.data.length + temp67];
                                        var13 = var5;
                                        var14 = 0x09e5;
                                        var15 = temp66;
                                        var14 = func_0D5A(var15);
                                        memory[var14:var14 + 0x20] = var13;
                                        var13 = var1;
                                        var14 = 0x09f0;
                                        var15 = var9;
                                        var14 = func_0D7B(var15);
                                        memory[var14:var14 + 0x20] = var13;
                                    
                                        if (!address(0x10ed43c718714eb63d5aa57b78b54704e256024e).code.length) { revert(memory[0x00:0x00]); }
                                    
                                        var temp68 = var9;
                                        var temp69 = var11;
                                        var temp70 = memory[0x40:0x60];
                                        var9 = temp70;
                                        var11 = var9;
                                        memory[var11:var11 + 0x20] = 0x5c11d795 << 0xe0;
                                        memory[var11 + 0x04:var11 + 0x04 + 0x20] = var12;
                                        memory[var11 + 0x24:var11 + 0x24 + 0x20] = 0x00;
                                        memory[var11 + 0x44:var11 + 0x44 + 0x20] = 0xa0;
                                        var temp71 = memory[temp68:temp68 + 0x20];
                                        memory[var11 + 0xa4:var11 + 0xa4 + 0x20] = temp71;
                                        var12 = var11 + 0xc4;
                                        var13 = temp69;
                                        var14 = 0x00;
                                        var15 = temp71;
                                    
                                        if (var14 >= var15) { goto label_0A4A; }
                                    
                                    label_0A9C:
                                        var temp72 = var13;
                                        var temp73 = var12;
                                        memory[temp73:temp73 + 0x20] = memory[temp72:temp72 + 0x20] & (0x01 << 0xa0) - 0x01;
                                        var11 = var9;
                                        var12 = temp73 + 0x20;
                                        var13 = temp72 + 0x20;
                                        var15 = var15;
                                        var14 = var14 + 0x01;
                                    
                                        if (var14 < var15) { goto label_0A9C; }
                                    
                                    label_0A4A:
                                        var temp74 = var11;
                                        memory[temp74 + 0x64:temp74 + 0x64 + 0x20] = address(this);
                                        memory[temp74 + 0x84:temp74 + 0x84 + 0x20] = block.timestamp;
                                        var temp75;
                                        temp75, memory[temp74:temp74 + 0x00] = address(0x10ed43c718714eb63d5aa57b78b54704e256024e).call.gas(msg.gas)(memory[temp74:temp74 + var12 - temp74]);
                                        var temp76 = var9;
                                        var11 = temp76;
                                    
                                        if (!temp75) { goto label_01A1; }
                                    
                                        var9 = 0x01;
                                    
                                        if (!var9) { goto label_0A86; }
                                    
                                        var12 = 0x00;
                                        var13 = var11;
                                        var11 = 0x0a96;
                                        func_0CF8(var12, var13);
                                        var11 = var0;
                                    
                                    label_0A86:
                                    
                                    label_09B6:
                                        var9 = var10 + 0x01;
                                    
                                        if (var9 < var3) { goto label_07C1; }
                                        else { goto label_0772; }
                                    }
                                }
                            } else {
                                var temp77 = var11 & var10;
                                var temp78 = var6;
                                var10 = temp77 * temp78;
                            
                                if (!(!temp77 | (temp78 == var10 / temp77))) { goto label_04E3; }
                                else { goto label_080A; }
                            }
                        } else {
                            var9 = 0x0192;
                            var10 = var8;
                            var11 = var7;
                            func_0CF8(var10, var11);
                            goto label_0192;
                        }
                    } else {
                        var9 = 0x0192;
                        var10 = var8;
                        var11 = var7;
                        func_0CF8(var10, var11);
                        goto label_0192;
                    }
                }
            }
        } else if (var0 == 0x13af4035) {
            // Dispatch table entry for setOwner(address)
            if (msg.value) { revert(memory[0x00:0x00]); }
        
            if (msg.data.length + ~0x03 i< 0x20) { revert(memory[0x00:0x00]); }
        
            var1 = 0x05b6;
            var1 = func_0CB8();
            var2 = 0x05ca;
            var3 = msg.sender == storage[0x00] & (0x01 << 0xa0) - 0x01;
            func_0D8B(var3);
            storage[0x00] = (var1 & (0x01 << 0xa0) - 0x01) | (storage[0x00] & ~((0x01 << 0xa0) - 0x01));
            stop();
        } else if (var0 == 0x195be17a) {
            // Dispatch table entry for 0x195be17a (unknown)
            if (msg.value) { revert(memory[0x00:0x00]); }
        
            if (msg.data.length + ~0x03 i< 0x00) { revert(memory[0x00:0x00]); }
        
            var temp79 = memory[0x40:0x60];
            memory[temp79:temp79 + 0x20] = 0x8f73b65b4caaf64fba2af91cc5d4a2a1318e5d8c;
            return memory[temp79:temp79 + 0x20];
        } else if (var0 == 0x65ac0565) {
            // Dispatch table entry for 0x65ac0565 (unknown)
            if (msg.data.length + ~0x03 i< 0xe0) { revert(memory[0x00:0x00]); }
        
            var1 = 0x0294;
            var1 = func_0CB8();
            var2 = 0x029c;
            var2 = func_0CCE();
            var temp80 = msg.data[0x44:0x64];
            var temp81 = var1;
            var1 = temp80 & (0x01 << 0xa0) - 0x01;
            var3 = temp81;
        
            if (temp80 - var1) { revert(memory[0x00:0x00]); }
        
            var4 = 0x02c6;
            var5 = msg.sender == storage[0x00] & (0x01 << 0xa0) - 0x01;
            func_0D8B(var5);
            var temp82 = memory[0x40:0x60];
            memory[temp82:temp82 + 0x20] = 0x70a08231 << 0xe0;
            memory[temp82 + 0x04:temp82 + 0x04 + 0x20] = address(this);
            var4 = var2;
            var temp83;
            temp83, memory[temp82:temp82 + 0x20] = address(var1).staticcall.gas(msg.gas)(memory[temp82:temp82 + 0x24]);
            var5 = temp82;
        
            if (!temp83) { goto label_01A1; }
        
            var2 = 0x00;
        
            if (!var2) { goto label_02F1; }
        
            var temp84 = var5;
            var temp85 = var4;
            var4 = temp84;
            var2 = temp85;
            var5 = 0x20;
            var6 = var4;
        
            if (0x20 <= returndata.length) { goto label_054A; }
        
            var5 = returndata.length;
        
        label_054A:
            var temp86 = var5;
            var7 = temp86;
            var8 = 0x0557;
            var5 = 0x20;
            var9 = var7;
            var10 = var6;
            func_0CF8(var9, var10);
            var temp87 = var6;
        
            if ((temp87 + var7) - temp87 i< var5) { revert(memory[0x00:0x00]); }
        
            var temp88 = var2;
            var2 = memory[var4:var4 + 0x20];
            var4 = temp88;
            var5 = var0;
        
        label_02F1:
            var temp89 = memory[0x40:0x60];
            var temp90 = var4;
            var4 = temp89;
            var temp91 = var3;
            var3 = var4 + 0x20;
            memory[var3:var3 + 0x20] = temp91 & (0x01 << 0xa0) - 0x01;
            memory[var4 + 0x40:var4 + 0x40 + 0x20] = temp90 & (0x01 << 0xa0) - 0x01;
            memory[var4 + 0x60:var4 + 0x60 + 0x20] = var1;
            memory[var4 + 0x80:var4 + 0x80 + 0x20] = msg.data[0x84:0xa4];
            memory[var4 + 0xa0:var4 + 0xa0 + 0x20] = msg.data[0xa4:0xc4];
            memory[var4:var4 + 0x20] = 0xa0;
            var5 = 0x0337;
            var6 = 0xc0;
            var7 = var4;
            func_0CF8(var6, var7);
        
            if (!address(0x8f73b65b4caaf64fba2af91cc5d4a2a1318e5d8c).code.length) { revert(memory[0x00:0x00]); }
        
            var temp92 = var4;
            var4 = 0x00;
            var6 = 0x84;
            var temp93 = memory[0x40:0x60];
            var7 = temp93;
            var temp94 = var3;
            var3 = var7;
            var5 = var3;
            memory[var5:var5 + 0x20] = 0x701195a1 << 0xe1;
            memory[var5 + 0x04:var5 + 0x04 + 0x20] = var1;
            memory[var5 + 0x24:var5 + 0x24 + 0x20] = msg.data[0x64:0x84];
            memory[var5 + 0x44:var5 + 0x44 + 0x20] = 0x60;
            var9 = memory[temp92:temp92 + 0x20];
            var10 = temp94;
            var8 = var9;
            memory[var5 + 0x64:var5 + 0x64 + 0x20] = var8;
            var11 = var5 + var6;
            // Unhandled termination
        } else if (var0 == 0x75b26293) {
            // Dispatch table entry for 0x75b26293 (unknown)
            if (msg.value) { revert(memory[0x00:0x00]); }
        
            if (msg.data.length + ~0x03 i< 0x00) { revert(memory[0x00:0x00]); }
        
            var temp95 = memory[0x40:0x60];
            memory[temp95:temp95 + 0x20] = storage[0x01] & (0x01 << 0xa0) - 0x01;
            return memory[temp95:temp95 + 0x20];
        } else if (var0 == 0x8da5cb5b) {
            // Dispatch table entry for owner()
            if (msg.value) { revert(memory[0x00:0x00]); }
        
            if (msg.data.length + ~0x03 i< 0x00) { revert(memory[0x00:0x00]); }
        
            var temp96 = memory[0x40:0x60];
            memory[temp96:temp96 + 0x20] = storage[0x00] & (0x01 << 0xa0) - 0x01;
            return memory[temp96:temp96 + 0x20];
        } else if (var0 == 0xa733396d) {
            // Dispatch table entry for 0xa733396d (unknown)
            if (msg.value) { revert(memory[0x00:0x00]); }
        
            if (msg.data.length + ~0x03 i< 0x20) { revert(memory[0x00:0x00]); }
        
            var1 = 0x01fb;
            var1 = func_0CB8();
            var2 = 0x020f;
            var3 = msg.sender == storage[0x00] & (0x01 << 0xa0) - 0x01;
            func_0D8B(var3);
            storage[0x01] = (var1 & (0x01 << 0xa0) - 0x01) | (storage[0x01] & ~((0x01 << 0xa0) - 0x01));
            stop();
        } else if (var0 == 0xaea7314d) {
            // Dispatch table entry for 0xaea7314d (unknown)
            if (msg.value) { revert(memory[0x00:0x00]); }
        
            if (msg.data.length + ~0x03 i< 0x40) { revert(memory[0x00:0x00]); }
        
            var1 = 0x00e1;
            var1 = func_0CB8();
            var2 = 0x00e9;
            var2 = func_0CCE();
            var temp97 = var2;
            var2 = var1;
            var1 = temp97;
            var3 = 0x00fe;
            var4 = msg.sender == storage[0x00] & (0x01 << 0xa0) - 0x01;
            func_0D8B(var4);
            var temp98 = memory[0x40:0x60];
            memory[temp98:temp98 + 0x20] = 0x70a08231 << 0xe0;
            memory[temp98 + 0x04:temp98 + 0x04 + 0x20] = address(this);
            var temp99 = var1;
            var1 = var2 & (0x01 << 0xa0) - 0x01;
            var3 = temp99;
            var temp100;
            temp100, memory[temp98:temp98 + 0x20] = address(var1).staticcall.gas(msg.gas)(memory[temp98:temp98 + 0x24]);
            var4 = temp98;
        
            if (!temp100) { goto label_01A1; }
        
            var2 = 0x00;
        
            if (!var2) { goto label_0135; }
        
            var temp101 = var4;
            var2 = temp101;
            var4 = 0x20;
            var5 = var2;
        
            if (0x20 <= returndata.length) { goto label_01BA; }
        
            var4 = returndata.length;
        
        label_01BA:
            var temp102 = var4;
            var6 = temp102;
            var7 = 0x01c7;
            var4 = 0x20;
            var8 = var6;
            var9 = var5;
            func_0CF8(var8, var9);
            var temp103 = var5;
        
            if ((temp103 + var6) - temp103 i< var4) { revert(memory[0x00:0x00]); }
        
            var2 = memory[var2:var2 + 0x20];
            var3 = var3;
            var4 = 0x0169;
        
        label_0135:
            var temp104 = memory[0x40:0x60];
            memory[temp104:temp104 + 0x20] = 0xa9059cbb << 0xe0;
            memory[temp104 + 0x04:temp104 + 0x04 + 0x20] = var3 & (0x01 << 0xa0) - 0x01;
            memory[temp104 + 0x24:temp104 + 0x24 + 0x20] = var2;
            var temp105 = var1;
            var1 = temp104;
            var temp106;
            temp106, memory[var1:var1 + 0x20] = address(temp105).call.gas(msg.gas)(memory[var1:var1 + (var1 + 0x44) - var1]);
        
            if (!temp106) { goto label_01A1; }
        
            if (var2) { goto label_0179; }
            else { stop(); }
        } else if (var0 != 0xff1a1600) {
            var0 = 0x00;
        
        label_000F:
        
            if (!msg.data.length) { stop(); }
            else { revert(memory[0x00:0x00]); }
        } else if (msg.value) { revert(memory[0x00:0x00]); }
        else if (msg.data.length + ~0x03 i< 0x00) { revert(memory[0x00:0x00]); }
        else {
            var temp107 = memory[0x40:0x60];
            memory[temp107:temp107 + 0x20] = 0x1b81d678ffb9c0263b24a97847620c99d213eb14;
            return memory[temp107:temp107 + 0x20];
        }
    }
    
    function func_019A(var arg0, var arg1) returns (var r0) {
        arg1 = returndata.length;
        var var0 = 0x0192;
        var var1 = arg1;
        var var2 = arg0;
        func_0CF8(var1, var2);
        var temp0 = arg0;
        arg0 = temp0 + arg1;
        arg1 = temp0;
        var temp1 = arg0;
        arg0 = arg1;
    
        if (temp1 - arg0 i< 0x20) { revert(memory[0x00:0x00]); }
    
        var temp2 = memory[arg0:arg0 + 0x20];
        arg0 = temp2;
    
        if (arg0 - !!arg0) { revert(memory[0x00:0x00]); }
        else { return arg0; }
    }
    
    function func_0CB8() returns (var r0) {
        var temp0 = msg.data[0x04:0x24];
        var var0 = r0;
        r0 = temp0;
    
        if (r0 - (r0 & (0x01 << 0xa0) - 0x01)) { revert(memory[0x00:0x00]); }
        else { return r0; }
    }
    
    function func_0CCE() returns (var r0) {
        var temp0 = msg.data[0x24:0x44];
        var var0 = r0;
        r0 = temp0;
    
        if (r0 - (r0 & (0x01 << 0xa0) - 0x01)) { revert(memory[0x00:0x00]); }
        else { return r0; }
    }
    
    function func_0CE4(var arg0) returns (var r0) {
        var temp0 = msg.data[arg0:arg0 + 0x20];
        arg0 = r0;
        r0 = temp0;
    
        if (r0 - (r0 & (0x01 << 0xa0) - 0x01)) { revert(memory[0x00:0x00]); }
        else { return r0; }
    }
    
    function func_0CF8(var arg0, var arg1) {
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
    
    function func_0D46(var arg0) returns (var r0) {
        var temp0 = memory[arg0:arg0 + 0x20];
        arg0 = r0;
        r0 = temp0;
    
        if (r0 - (r0 & (0x01 << 0x70) - 0x01)) { revert(memory[0x00:0x00]); }
        else { return r0; }
    }
    
    function func_0D5A(var arg0) returns (var r0) {
        if (memory[arg0:arg0 + 0x20]) { return arg0 + 0x20; }
    
        memory[0x00:0x20] = 0x4e487b71 << 0xe0;
        memory[0x04:0x24] = 0x32;
        revert(memory[0x00:0x24]);
    }
    
    function func_0D7B(var arg0) returns (var r0) {
        if (0x01 < memory[arg0:arg0 + 0x20]) { return arg0 + 0x40; }
    
        memory[0x00:0x20] = 0x4e487b71 << 0xe0;
        memory[0x04:0x24] = 0x32;
        revert(memory[0x00:0x24]);
    }
    
    function func_0D8B(var arg0) {
        if (arg0) { return; }
    
        var temp0 = memory[0x40:0x60];
        memory[temp0:temp0 + 0x20] = 0x461bcd << 0xe5;
        memory[temp0 + 0x04:temp0 + 0x04 + 0x20] = 0x20;
        memory[temp0 + 0x24:temp0 + 0x24 + 0x20] = 0x09;
        memory[temp0 + 0x44:temp0 + 0x44 + 0x20] = 0x3737ba1037bbb732b9 << 0xb9;
        revert(memory[temp0:temp0 + 0x64]);
    }
}

