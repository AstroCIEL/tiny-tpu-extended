import os

def generate_hex_file_input(input_filename, output_filename):
    # 矩阵维度定义
    ROWS = 16
    COLS = 256
    
    # 1. 读取并解析数据
    try:
        with open(input_filename, 'r', encoding='utf-8') as f:
            content = f.read()
            # 将所有空白字符（空格、换行）作为分隔符，并将非空字符串转为int
            # 过滤掉可能的非数字字符（如 这种标签，如果原文件包含的话）
            # 这里假设 input.txt 主要是数字。如果包含 ""，我们需要简单清洗一下。
            clean_data = []
            for item in content.split():
                # 简单的清洗逻辑：尝试转换数字，如果失败则跳过（用于跳过source标签）
                # 同时也处理可能的标点
                if item.replace('[', '').replace(']', '').replace(':', '').isdigit():
                    # 这是一个纯数字或者类似索引的东西，但根据你的描述，正文是矩阵数据
                    # 为了安全起见，这里假设文件里除了标签外全是矩阵数据
                    # 如果原文件包含 ，通常那是元数据，我们只取纯数字流
                    pass
                
                # 更稳健的方法：只提取纯数字
                if item.isdigit():
                    clean_data.append(int(item))
                elif '[' in item: # 跳过 这种标记
                    continue

    except FileNotFoundError:
        print(f"错误: 找不到文件 {input_filename}")
        return

    # 检查数据量是否符合 16x256
    if len(clean_data) < ROWS * COLS:
        print(f"警告: 数据量不足。期望 {ROWS*COLS} 个数字，实际读取到 {len(clean_data)} 个。")
        # 补零以防崩溃
        clean_data += [0] * (ROWS * COLS - len(clean_data))
    
    # 将一维列表转换为二维矩阵 matrix[row][col]
    matrix = [clean_data[i*COLS : (i+1)*COLS] for i in range(ROWS)]

    print(f"成功读取矩阵: {len(matrix)} 行, {len(matrix[0])} 列")

    # 2. 按照映射逻辑生成 Hex 数据
    # 逻辑回顾：
    # 内存宽度 512 bit = 64 Bytes = 128 Hex Char
    # 每个 input_memory[i] 包含 4 行数据，每行 16 个 8-bit 数
    # input_memory[0] 包含: Row 3, Row 2, Row 1, Row 0 的前16个数
    # 存放顺序：Readmemh 读入 Hex 字符串是从左到右对应 MSB 到 LSB
    # 题目要求：Row 0 (第1行) -> [127:0] (LSB部分)
    #          Row 3 (第4行) -> [511:384] (MSB部分)
    # 所以 Hex 字符串的顺序应该是：Hex(Row3) + Hex(Row2) + Hex(Row1) + Hex(Row0)
    
    # 列分块：每 16 列为一大块
    # 行分块：每 4 行为一小块
    
    hex_lines = []
    
    # 外层循环：列块 (0~15, 16~31, ..., 240~255) -> 对应 input_memory 的索引跨度
    num_col_blocks = COLS // 16 # 256/16 = 16
    num_row_blocks = ROWS // 4  # 16/4 = 4
    
    for c_blk in range(num_col_blocks):
        col_start = c_blk * 16
        
        # 内层循环：行块 (0~3, 4~7, ...) -> 对应 input_memory 的连续地址
        for r_blk in range(num_row_blocks):
            row_start = r_blk * 4
            
            line_hex_str = ""
            
            # 构建 512-bit 的行数据
            # 顺序：Row 3 (高位) -> Row 0 (低位)
            # 在 row_start 基础上，偏移量从 3 递减到 0
            for r_offset in range(3, -1, -1): 
                curr_row = row_start + r_offset
                
                # 在当前行内，处理 16 个 8-bit 数
                # 这一段 128-bit 数据中，题目未明示列的 MSB/LSB 顺序，
                # 但通常 memory[127:0] 中 [7:0] 是第一个数（Col 0），[127:120] 是第16个数（Col 15）。
                # Hex 字符串左侧是 MSB。
                # 所以为了让 Col 0 落入 LSB，Col 15 必须在 Hex 字符串的左侧，Col 0 在右侧。
                # 遍历顺序：Col 15 -> Col 0
                # for c_offset in range(15, -1, -1):
                for c_offset in range(16):
                    curr_col = col_start + c_offset
                    val = matrix[curr_row][curr_col]
                    
                    # 确保是8bit (0-255)，转为2位16进制
                    line_hex_str += f"{val & 0xFF:02x}"
            
            hex_lines.append(line_hex_str)

    # 3. 写入文件
    try:
        with open(output_filename, 'w') as f:
            for line in hex_lines:
                f.write(line + "\n")
        print(f"成功生成文件: {output_filename}")
        print(f"总行数: {len(hex_lines)} (每行 512 bits)")
        print(f"对应逻辑: input_memory[0] 到 input_memory[{len(hex_lines)-1}]")
    except IOError:
        print(f"无法写入文件 {output_filename}")

def generate_hex_file_weight(input_file: str, output_file: str) -> None:
    with open(input_file, 'r') as f:
        lines = f.readlines()

    data_matrix = []
    for line_num, line in enumerate(lines):
        numbers = line.strip().split()
        
        int_numbers = []
        for num_str in numbers:
            num = int(num_str)
            if num < 0:
                num_8bit = (1 << 8) + num
            else:
                num_8bit = num
                
            int_numbers.append(num_8bit)
        data_matrix.append(int_numbers)
    
    print(f"成功读取输入文件：{len(data_matrix)}行，每行{len(data_matrix[0])}个数")

    output_lines = []
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
        output_lines.append(''.join(hex_line))

    with open(output_file, 'w') as f:
        for line in output_lines:
            f.write(line + '\n')
    
    print(f"成功写入输出文件：{len(output_lines)}行，每行{len(output_lines[0])}个十六进制字符")

def get_matrix(input_file: str):
    if not os.path.exists(input_file):
        print(f"Error: {input_file} not found.")
        return []
    
    with open(input_file, 'r') as f:
        lines = f.readlines()

    data_matrix = []
    for line in lines:
        numbers = line.strip().split()
        if not numbers: continue
        int_numbers = [int(num_str) for num_str in numbers]
        data_matrix.append(int_numbers)
    
    print(f"Loaded {input_file}: {len(data_matrix)} rows x {len(data_matrix[0])} cols")
    return data_matrix

def matrix_multiply_and_scale(A, B_T, scale: float):
    """
    1. A (m x k) * B_T (n x k) 的转置 -> (m x n)
    2. Result * scale
    3. Round to nearest integer & Clamp to int8 range [-128, 127]
    """
    m = len(A)
    k = len(A[0])
    n = len(B_T)
    
    result = [[0 for _ in range(n)] for _ in range(m)]
    
    for i in range(m):
        for j in range(n):
            # 1. 矩阵乘法累加 (通常使用更高的精度，如 int32)
            acc = 0
            for l in range(k):
                acc += A[i][l] * B_T[j][l]
            
            # 2. 缩放
            scaled_val = acc * scale
            
            # 3. 四舍五入并截断到 int8 范围
            # 使用 round() 进行最近舍入，并使用 min/max 限制范围
            final_val = int(round(scaled_val))
            final_val = max(-128, min(127, final_val))
            
            result[i][j] = final_val
            
    return result

def save_matrix(matrix, output_file):
    with open(output_file, 'w') as f:
        for row in matrix:
            # 将 int8 结果写入文件
            line = " ".join(map(str, row))
            f.write(line + "\n")
    print(f"Quantized result saved to {output_file}")
    
import struct

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



test_name='test_2'
SCALE_FACTOR = 0.0030  # 示例 fp32 scale 数

result = float_to_fp32_binary(SCALE_FACTOR)
print(f"数字: {SCALE_FACTOR}")
print(f"二进制表示: {result['formatted']}")
print(f"十六进制: {result['hex']}")

input_file_dec = f'input_{test_name}_dec.txt'
weight_file_dec = f'weight_{test_name}_dec.txt'
input_file_hex = f'input_{test_name}_hex.txt'
weight_file_hex = f'weight_{test_name}_hex.txt'

with open(weight_file_dec, "w") as f:
    for _ in range(4):
        for i in range(1, 17):
            # 创建包含16个数字的列表，并用空格连接
            for j in range(16):
                line = " ".join([str(i-j)] * 16)
                f.write(line + " ")
            f.write("\n")
with open(input_file_dec, "w") as f:
    for i in range(1, 17):
        # 创建包含16个数字的列表，并用空格连接
        for j in range(16):
            line = " ".join([str(i+j)] * 16)
            f.write(line + " ")
        f.write("\n")
        
generate_hex_file_input(input_file_dec,input_file_hex)
generate_hex_file_weight(weight_file_dec,weight_file_hex)

w_test = get_matrix(weight_file_dec) # 64 x 256
a_test = get_matrix(input_file_dec)  # 16 x 256

if w_test and a_test:
    print(f"Calculating A * W^T with scale {SCALE_FACTOR}...")
    
    # 执行带缩放和量化的运算
    res_int8 = matrix_multiply_and_scale(a_test, w_test, SCALE_FACTOR)
    
    print(f"Result matrix size: {len(res_int8)} row x {len(res_int8[0])} col")
    save_matrix(res_int8, f"output_golden_{test_name}.txt")