`timescale 1ns/1ps

module tb_systolic_array;

    // 时钟和复位
    logic clk;
    logic rst;
    
    // 4x16x16阵列接口
    logic sa_enable [3:0];
    logic signed [7:0] sa_input [15:0];
    logic sa_valid_in;
    logic signed [7:0] sa_weight [3:0][15:0];
    logic sa_new_weight;
    logic sa_switch_in;
    logic signed [31:0] sa_output [3:0][15:0];
    logic sa_valid_out [3:0][15:0];
    
    // 实例化被测模块
    systolic_array dut (
        .clk(clk),
        .rst(rst),
        .sa_enable(sa_enable),
        .sa_input(sa_input),
        .sa_valid_in(sa_valid_in),
        .sa_weight(sa_weight),
        .sa_new_weight(sa_new_weight),
        .sa_switch_in(sa_switch_in),
        .sa_output(sa_output),
        .sa_valid_out(sa_valid_out)
    );
    
    // 时钟生成
    initial begin
        clk = 0;
        forever #5 clk = ~clk;  // 100MHz时钟
    end
    
    // 原始测试数据：两组16x16权重和输入
    logic signed [7:0] weight_matrix_1 [15:0][15:0];
    logic signed [7:0] weight_matrix_2 [15:0][15:0];
    logic signed [7:0] input_matrix_1 [15:0][15:0];
    logic signed [7:0] input_matrix_2 [15:0][15:0];
    
    // 对角线重排后的数据：16x47
    logic signed [7:0] weight_diagonal_1 [46:0][15:0];
    logic signed [7:0] weight_diagonal_2 [46:0][15:0];  // 两个对角重排矩阵
    logic signed [7:0] input_diagonal [46:0][15:0];
    
    // 期望输出：两组16x16矩阵乘法的结果
    logic signed [31:0] expected_output_11 [15:0][15:0];
    logic signed [31:0] expected_output_12 [15:0][15:0];
    logic signed [31:0] expected_output_21 [15:0][15:0];
    logic signed [31:0] expected_output_22 [15:0][15:0];
    
    // 输入周期计数器（用于跟踪输出时序）
    int input_cycle_count = 0;
    
    // 初始化测试数据并进行对角线重排
    initial begin
        // 初始化第一组权重
        for (int i = 0; i < 16; i++) begin
            for (int j = 0; j < 16; j++) begin
                weight_matrix_1[i][j] = i + 2*j + 1;
            end
        end
        
        // 初始化第二组权重
        for (int i = 0; i < 16; i++) begin
            for (int j = 0; j < 16; j++) begin
                weight_matrix_2[i][j] = i * 2 + j + 1;
            end
        end
        
        // 初始化第一组输入
        for (int i = 0; i < 16; i++) begin
            for (int j = 0; j < 16; j++) begin
                input_matrix_1[i][j] = (i == j) ? 8'd1 : 8'd0;
            end
        end
        
        // 初始化第二组输入
        for (int i = 0; i < 16; i++) begin
            for (int j = 0; j < 16; j++) begin
                input_matrix_2[i][j] = 8'd1;
            end
        end

        // 计算期望输出（矩阵乘法：output = input * weight）
        // 标准矩阵乘法：output[row][col] = sum(input[row][k] * weight[k][col]) for k = 0 to 15
        for (int row = 0; row < 16; row = row + 1) begin
            for (int col = 0; col < 16; col = col + 1) begin
                expected_output_11[row][col] = 0;
                expected_output_12[row][col] = 0;
                expected_output_21[row][col] = 0;
                expected_output_22[row][col] = 0;
                for (int k = 0; k < 16; k = k + 1) begin
                    expected_output_11[row][col] = expected_output_11[row][col] + 
                                                   input_matrix_1[row][k] * weight_matrix_1[k][col];
                    expected_output_12[row][col] = expected_output_12[row][col] + 
                                                   input_matrix_2[row][k] * weight_matrix_2[k][col];
                    expected_output_21[row][col] = expected_output_21[row][col] + 
                                                   input_matrix_1[row][k] * weight_matrix_2[k][col];
                    expected_output_22[row][col] = expected_output_22[row][col] + 
                                                   input_matrix_2[row][k] * weight_matrix_1[k][col];
                end
            end
        end
        
        // 对权重进行对角线重排
        // 第一列不动，第二列向上缩进1位，第三列向上缩进2位，以此类推
        for (int i = 0; i < 47; i = i + 1) begin    // i为行，j为列
            for (int j = 0; j < 16; j = j + 1) begin
                if (i < j || i - j > 31) begin //补0
                    weight_diagonal_1[i][j] = 8'b0;
                    weight_diagonal_2[i][j] = 8'b0;
                end else if (i - j < 16) begin
                    // 第j列，从第j行开始有数据
                    // 重排后矩阵的第i行第j列为weight1矩阵的第(15-j+i)行第j列
                    weight_diagonal_1[i][j] = weight_matrix_1[15-i+j][j];
                    weight_diagonal_2[i][j] = weight_matrix_2[15-i+j][j];
                end else begin
                    // 重排后矩阵的第i行第j列为weight2矩阵的第(15-j+(i-16))行第j列
                    weight_diagonal_1[i][j] = weight_matrix_2[31-i+j][j];
                    weight_diagonal_2[i][j] = weight_matrix_1[31-i+j][j];
                end
            end
        end
        
        // 对输入进行对角线重排
        for (int i = 0; i < 47; i = i + 1) begin    // i为列，j为行
            for (int j = 0; j < 16; j = j + 1) begin
                if (j > i || i - j > 31) begin //补0
                    input_diagonal[i][j] = 8'b0;
                end else if (i - j < 16) begin
                    // 第j行，从第j列开始有数据
                    // 重排后矩阵的第i列第j行为input1矩阵的第(i-j)列第j行
                    input_diagonal[i][j] = input_matrix_1[i-j][j];
                end else begin
                    // 重排后矩阵的第i列第j行为input2矩阵的第(i-j-16)列第j行
                    input_diagonal[i][j] = input_matrix_2[i-j-16][j];
                end
            end
        end
    end
    
    // 主测试流程
    initial begin
        // 初始化
        rst = 1'b1;
        sa_enable[0] = 1'b1;  
        sa_enable[1] = 1'b1;    // 使能Array 0与Array 1进行测试
        sa_enable[2] = 1'b0;
        sa_enable[3] = 1'b0;
        sa_valid_in = 1'b0;
        sa_new_weight = 1'b0;
        sa_switch_in = 1'b0;
        for (int i = 0; i < 16; i++) begin
            sa_input[i] = 8'b0;
        end
        for (int i = 0; i < 4; i++) begin
            for (int j = 0; j < 16; j++) begin
                sa_weight[i][j] = 8'b0;
            end
        end
        
        // 复位
        #20;
        rst = 1'b0;
        #6;
        
        $display("==========================================");
        $display("Test: Systolic Array with Diagonal Input");
        $display("==========================================");
        
        input_cycle_count = 0;
        
        // 初始化完成，开始测试流程
        
        // 1. 开始输入weight，持续16个周期
        for (int i = 0; i < 16; i++) begin
            # 10;
            sa_weight[0] = weight_diagonal_1[i];
            sa_weight[1] = weight_diagonal_2[i];
            input_cycle_count++;
        end

        // 2. 在第15个周期拉高new_weight信号
        sa_new_weight = 1'b1;

        // 3. 在第16个周期拉低new_weight信号，拉高switch信号，同时开始输入input
        # 10;
        sa_new_weight = 1'b0;
        sa_switch_in = 1'b1;
        sa_weight[0] = weight_diagonal_1[16];
        sa_weight[1] = weight_diagonal_2[16];
        input_cycle_count++;

        // 4. 在第17个周期拉高valid_in信号，同时开始输入input
        # 10;
        sa_switch_in = 1'b0;
        sa_valid_in = 1'b1;
        sa_input = input_diagonal[0];
        sa_weight[0] = weight_diagonal_1[17];
        sa_weight[1] = weight_diagonal_2[17];
        input_cycle_count++;

        // 5. 在第18个周期拉低switch信号
        # 10;
        sa_switch_in = 1'b0;
        sa_input = input_diagonal[1];
        sa_weight[0] = weight_diagonal_1[18];
        sa_weight[1] = weight_diagonal_2[18];
        input_cycle_count++;

        // 6. 继续输入剩余的input和weight
        for (int i = 19; i < 32; i++) begin
            # 10;
            sa_input = input_diagonal[i-17];
            sa_weight[0] = weight_diagonal_1[i];
            sa_weight[1] = weight_diagonal_2[i];
            input_cycle_count++;
        end 

        // 7. 在第31个周期拉高new_weight信号
        sa_new_weight = 1'b1;
        
        // 8. 在第32个周期拉低new_weight信号，拉高switch信号
        # 10;
        sa_new_weight = 1'b0;
        sa_switch_in = 1'b1;
        sa_input = input_diagonal[15];
        sa_weight[0] = weight_diagonal_1[32];
        sa_weight[1] = weight_diagonal_2[32];
        input_cycle_count++;

        // 9. 在第33个周期拉低switch信号
        # 10;
        sa_switch_in = 1'b0;
        sa_input = input_diagonal[16];
        sa_weight[0] = weight_diagonal_1[33];
        sa_weight[1] = weight_diagonal_2[33];
        input_cycle_count++;

        // 10. 继续输入剩余的input和weight
        for (int i = 34; i < 47; i++) begin
            # 10;
            sa_input = input_diagonal[i-17];
            sa_weight[0] = weight_diagonal_1[i];
            sa_weight[1] = weight_diagonal_2[i];
            input_cycle_count++;
        end
        # 10;
        sa_input = input_diagonal[30];
        input_cycle_count++;
        # 10;
        sa_input = input_diagonal[31];
        input_cycle_count++;

        // 11. 在第49个周期拉低valid_in信号
        # 10;
        sa_valid_in = 1'b0;
        sa_input = input_diagonal[32];
        input_cycle_count++;

        // 11. 输入剩余的input
        for (int i = 33; i < 47; i++) begin
            # 10;
            sa_input = input_diagonal[i];
            input_cycle_count++;
        end

        // 14. 延迟16个周期，等待输出结果
        repeat(16) # 10;

        #(19);
        $finish;
    end
    
    //display inputs & outputs as waveform
    initial begin
        // 指定输出波形文件名
        $fsdbDumpfile("sa_wave.fsdb");
        // 0 表示 dump 所有层次，tb_top 是顶层模块名
        $fsdbDumpvars("+all");
        // 如果想 dump 数组（Unified Buffer需要），需要加上这个
        $fsdbDumpMDA(); 
    end

endmodule