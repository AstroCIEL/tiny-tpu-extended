import sys
import os
from typing import List

def convert_file_to_readmemh(input_file: str, output_file: str) -> None:
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

def main(): 
    input_file = sys.argv[1]
    output_file = sys.argv[2]
    
    convert_file_to_readmemh(input_file, output_file)
    print("转换完成！")

if __name__ == "__main__":
    main()