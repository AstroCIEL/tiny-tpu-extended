import os
import random
import struct

def generate_hex_file_input(input_filename, output_filename):
    # 矩阵维度定义
    ROWS = 16
    COLS = 256
    
    # 1. 读取并解析数据
    try:
        with open(input_filename, 'r', encoding='utf-8') as f:
            content = f.read()
            clean_data = []
            for item in content.split():
                if item.isdigit() or (item.startswith('-') and item[1:].isdigit()):
                    clean_data.append(int(item))
                elif '[' in item: 
                    continue
    except FileNotFoundError:
        print(f"错误: 找不到文件 {input_filename}")
        return

    if len(clean_data) < ROWS * COLS:
        print(f"警告: 数据量不足。期望 {ROWS*COLS} 个数字，实际读取到 {len(clean_data)} 个。")
        clean_data += [0] * (ROWS * COLS - len(clean_data))
    
    matrix = [clean_data[i*COLS : (i+1)*COLS] for i in range(ROWS)]
    print(f"成功读取矩阵: {len(matrix)} 行, {len(matrix[0])} 列")

    hex_lines = []
    num_col_blocks = COLS // 16 
    num_row_blocks = ROWS // 4  
    
    for c_blk in range(num_col_blocks):
        col_start = c_blk * 16
        for r_blk in range(num_row_blocks):
            row_start = r_blk * 4
            line_hex_str = ""
            for r_offset in range(3, -1, -1): 
                curr_row = row_start + r_offset
                for c_offset in range(16):
                    curr_col = col_start + c_offset
                    val = matrix[curr_row][curr_col]
                    line_hex_str += f"{val & 0xFF:02x}"
            hex_lines.append(line_hex_str)

    with open(output_filename, 'w') as f:
        for line in hex_lines:
            f.write(line + "\n")
    print(f"成功生成文件: {output_filename}")

def generate_hex_file_weight(input_file: str, output_file: str) -> None:
    # 1. 读取并解析输入文件
    if not os.path.exists(input_file):
        print(f"错误：找不到文件 {input_file}")
        return

    with open(input_file, 'r') as f:
        lines = f.readlines()

    data_matrix = []
    for line in lines:
        numbers = line.strip().split()
        if not numbers: continue
        
        int_numbers = []
        for num_str in numbers:
            num = int(num_str)
            # 处理 8-bit 补码
            if num < 0:
                num_8bit = (1 << 8) + num
            else:
                num_8bit = num
            int_numbers.append(num_8bit)
        data_matrix.append(int_numbers)
    
    print(f"成功读取输入文件：{len(data_matrix)}行，每行{len(data_matrix[0])}个数")

    # 2. 生成原始的 Hex 行数据 (按 position 循环)
    # 此时生成的 output_lines 共有 256 行
    raw_output_lines = []
    for position in range(256):
        position_numbers = []
        for row in range(64):
            position_numbers.append(data_matrix[row][position])

        hex_line = []
        for i in range(0, 64, 4):
            group = position_numbers[i:i+4]
            value_32bit = 0
            for j, num in enumerate(group):
                value_32bit |= (num << (24 - j * 8))
            hex_str = format(value_32bit, '08x')
            hex_line.append(hex_str)
        raw_output_lines.append(''.join(hex_line))

    # 3. 新增逻辑：以每 16 行为一组，组内行顺序倒置
    # 256 行会被分成 16 组（256/16 = 16）
    final_output_lines = []
    group_size = 16
    
    for i in range(0, len(raw_output_lines), group_size):
        # 获取当前组 (16行)
        current_group = raw_output_lines[i : i + group_size]
        # 使用 [::-1] 将组内列表倒置并添加到最终结果中
        final_output_lines.extend(current_group[::-1])

    # 4. 写入输出文件
    with open(output_file, 'w') as f:
        for line in final_output_lines:
            f.write(line + '\n')
    
    print(f"成功写入输出文件：{len(final_output_lines)}行")

def get_matrix(input_file: str):
    if not os.path.exists(input_file): return []
    with open(input_file, 'r') as f:
        lines = f.readlines()
    data_matrix = []
    for line in lines:
        numbers = line.strip().split()
        if not numbers: continue
        data_matrix.append([int(num_str) for num_str in numbers])
    return data_matrix

def matrix_multiply_and_scale(A, B_T, scale: float):
    m, k, n = len(A), len(A[0]), len(B_T)
    result = [[0 for _ in range(n)] for _ in range(m)]
    for i in range(m):
        for j in range(n):
            acc = sum(A[i][l] * B_T[j][l] for l in range(k))
            final_val = max(-128, min(127, int(round(acc * scale))))
            result[i][j] = final_val
    return result

def save_matrix(matrix, output_file):
    with open(output_file, 'w') as f:
        for row in matrix:
            f.write(" ".join(map(str, row)) + "\n")
    print(f"结果已保存至 {output_file}")

# --- 新增函数：计算并保存16个中间步骤的结果 ---
def save_intermediate_steps(A, B_T, output_file):
    """
    将 256 维的计算拆分为 16 个 Step，每个 Step 计算 16 列的乘加结果。
    每个 Step 输出一个 16x64 的矩阵（Partial Sums）。
    """
    m = len(A)      # 16
    k = len(A[0])   # 256
    n = len(B_T)    # 64
    num_steps = k // 16 # 16 次
    
    with open(output_file, 'w') as f:
        for step in range(num_steps):
            f.write(f"--- Step {step} (Input/Weight Cols {step*16} to {step*16+15}) ---\n")
            col_start = step * 16
            col_end = col_start + 16
            
            for i in range(m):
                row_partials = []
                for j in range(n):
                    # 计算当前 16 列对应的部分和
                    p_sum = sum(A[i][l] * B_T[j][l] for l in range(col_start, col_end))
                    row_partials.append(str(p_sum))
                f.write(" ".join(row_partials) + "\n")
            f.write("\n")
    print(f"中间过程已保存至 {output_file}")

def float_to_fp32_binary(num: float):
    """
    将浮点数转换为 IEEE 754 标准的 32位二进制字符串
    """
    # 'f' 代表 float (32 bit), 'I' 代表 unsigned int (32 bit)
    # struct.pack 将浮点数打包为字节，struct.unpack 将字节解释为无符号整数
    packed = struct.pack('!f', num) # 使用大端序 (network byte order)
    integ = struct.unpack('!I', packed)[0]
    
    # 转换为 32 位二进制字符串，不足位补 0
    binary_str = f"{integ:032b}"
    
    # 为了方便阅读，将其拆分为：符号位(1) - 指数位(8) - 尾数位(23)
    sign = binary_str[0]
    exponent = binary_str[1:9]
    mantissa = binary_str[9:]
    
    return {
        "full": binary_str,
        "formatted": f"{sign}_{exponent}_{mantissa}",
        "hex": hex(integ).upper()
    }

# 主流程
test_name = 'test_2'
SCALE_FACTOR = 0.0011538403
input_file_dec = f'input_{test_name}_dec.txt'
weight_file_dec = f'weight_{test_name}_dec.txt'
input_file_hex = f'input_{test_name}_hex.txt'
weight_file_hex = f'weight_{test_name}_hex.txt'

result = float_to_fp32_binary(SCALE_FACTOR)
print(f"数字: {SCALE_FACTOR}")
print(f"二进制表示: {result['formatted']}")
print(f"十六进制: {result['hex']}")

# 数据生成逻辑 (保持不变)
random_weight = True
random_input = True

if random_weight:
    with open(weight_file_dec, "w") as f:
        for _ in range(4):  # 保持 4 个大块
            for i in range(1, 17):  # 每块 16 行
                for j in range(16):  # 每行 16 个小组
                    # 每一组生成 16 个随机数，并用空格连接
                    random_values = [str(random.randint(-32, 32)) for _ in range(16)]
                    line = " ".join(random_values)
                    f.write(line + " ")
                f.write("\n")
else:
    with open(weight_file_dec, "w") as f:
        for _ in range(4):
            for i in range(1, 17):
                # 创建包含16个数字的列表，并用空格连接
                for j in range(16):
                    # f.write(" ".join([str(i-j+1)] * 14) + " " + " ".join([str(i-j-1)] * 2) + " ")
                    f.write(" ".join([str(i-j+1)] * 15) + " " + str(3*i-j-16)+ " ")
                f.write("\n")

if random_input:
    with open(input_file_dec, "w") as f:
        for i in range(1, 17):  # 保持 16 行
            for j in range(16):  # 每行 16 个小组
                line1_vals = [str(random.randint(0, 32)) for _ in range(16)]
                f.write(" ".join(line1_vals) + " ")
            f.write("\n")
else:
    with open(input_file_dec, "w") as f:
        for i in range(1, 17):
            # 创建包含16个数字的列表，并用空格连接
            for j in range(16):
                line1 = " ".join([str(i+j)] * 8)
                line2 = " ".join([str(i+j-1)] * 8)
                f.write(line1 + " " + line2 + " ")
            f.write("\n")

generate_hex_file_input(input_file_dec, input_file_hex)
generate_hex_file_weight(weight_file_dec, weight_file_hex)

w_test = get_matrix(weight_file_dec)
a_test = get_matrix(input_file_dec)

if w_test and a_test:
    print(f"Calculating A * W^T with scale {SCALE_FACTOR}...")
    # 1. 保存最终的量化结果 (Golden Result)
    res_int8 = matrix_multiply_and_scale(a_test, w_test, SCALE_FACTOR)
    save_matrix(res_int8, f"output_golden_{test_name}.txt")
    
    # 2. 调用新增功能：保存 16 次矩阵乘法的中间部分和
    save_intermediate_steps(a_test, w_test, f"intermediate_results_{test_name}.txt")