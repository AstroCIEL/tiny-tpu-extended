import sys

def generate_hex_file(input_filename, output_filename):
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

if __name__ == "__main__":
    # 假设输入文件名为 input.txt
    generate_hex_file("input_dec.txt", "input_hex.txt")