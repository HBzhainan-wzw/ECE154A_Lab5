module tb();
  
    reg clk;
    reg reset;
    wire [31:0] writedata;
    wire [31:0] adr;
    wire memwrite;
    // instantiate device to be tested
    top mipstop(clk, reset,writedata,adr,memwrite);

    // initialize test 
    initial
        begin
            reset <= 1; # 22; reset <= 0;
        end
    // generate clock to sequence tests 
    always
        begin
            clk <= 1; # 5; clk <= 0; # 5;
        end

endmodule
