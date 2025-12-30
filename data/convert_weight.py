import sys
import os
from typing import List

def convert_file_to_readmemh(input_file: str, output_file: str) -> None:
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
    print(f"处理逻辑：每{group_size}行一组进行倒置处理完成。")

def main(): 
    input_file = 'weight_dec.txt'
    output_file = 'weight_hex.txt'
    
    convert_file_to_readmemh(input_file, output_file)
    print("转换完成！")

if __name__ == "__main__":
    main()