#!/usr/bin/env python3
'''
使用说明：
1.将 excel 内的指令部分复制粘贴进 txt, 转为无格式文档
2.python3 ins_convert.py <输入文档> <输出文档>
'''

import sys
import os
import argparse
from pathlib import Path

class InstructionConverter:
    def __init__(self, total_bits=54):
        self.total_bits = total_bits
        self.fields = [
            {"name": "field0", "range": "9:0",   "start": 0,  "width": 10, "binary_digits": None},
            {"name": "field1", "range": "19:10", "start": 10, "width": 10, "binary_digits": None},
            {"name": "field2", "range": "31:20", "start": 20, "width": 12, "binary_digits": None},
            {"name": "field3", "range": "35:32", "start": 32, "width": 4,  "binary_digits": None},
            {"name": "field4", "range": "39:36", "start": 36, "width": 4,  "binary_digits": None},
            {"name": "field5", "range": "41:40", "start": 40, "width": 2,  "binary_digits": 2},
            {"name": "field6", "range": "43:42", "start": 42, "width": 2,  "binary_digits": 2},
            {"name": "field7", "range": "44",    "start": 44, "width": 1,  "binary_digits": 1},
            {"name": "field8", "range": "45",    "start": 45, "width": 1,  "binary_digits": 1},
            {"name": "field9", "range": "46",    "start": 46, "width": 1,  "binary_digits": 1},
            {"name": "field10", "range": "48:47","start": 47, "width": 2,  "binary_digits": 2},
            {"name": "field11", "range": "49",   "start": 49, "width": 1,  "binary_digits": 1},
            {"name": "field12", "range": "50",   "start": 50, "width": 1,  "binary_digits": 1},
            {"name": "field13", "range": "51",   "start": 51, "width": 1,  "binary_digits": 1},
            {"name": "field14", "range": "52",   "start": 52, "width": 1,  "binary_digits": 1},
            {"name": "field15", "range": "53",   "start": 53, "width": 1,  "binary_digits": 1},
        ]
    
    def parse_value(self, value_str, expected_binary_digits=None):
        value_str = value_str.strip()
        
        if not value_str:
            return 0
            
        # 处理十六进制数（以0x开头）
        if value_str.lower().startswith("0x"):
            try:
                # 移除0x前缀并解析为16进制
                hex_value = value_str[2:]
                return int(hex_value, 16)
            except ValueError as e:
                print(f"错误: 无法解析十六进制数 '{value_str}': {e}")
                return 0
        
        # 处理二进制数（没有0x前缀）
        else:
            # 验证二进制字符串
            for char in value_str:
                if char not in '01':
                    print(f"警告: 二进制字符串 '{value_str}' 包含非二进制字符 '{char}'")
                    # 尝试继续解析，将无效字符视为0
                    pass
            
            # 解析二进制
            binary_value = int(value_str, 2)
            
            return binary_value
    
    def combine_fields(self, field_values, verbose=False):
        if len(field_values) != len(self.fields):
            raise ValueError(f"字段数量不匹配: 期望 {len(self.fields)}，实际 {len(field_values)}")
        
        instruction = 0
        
        for i, field in enumerate(self.fields):
            value = field_values[i]
            start_bit = field["start"]
            width = field["width"]
            
            # 检查值是否超出范围
            max_val = (1 << width) - 1
            if value > max_val:
                print(f"警告: 字段{field['range']}的值{value}(0x{value:x})超出{width}位范围(0-{max_val})")
                value = value & max_val  # 截断
            
            # 将值放置到正确的位置
            instruction |= (value << start_bit)
            
            if verbose:
                print(f"  字段{i}({field['range']}): 值={value}(0x{value:x}, 0b{value:0{width}b}), "
                      f"移位{start_bit}位 -> 0x{value << start_bit:x}")
        
        if verbose:
            print(f"  组合结果: 0x{instruction:x} = 0b{instruction:0{self.total_bits}b}")
        
        return instruction
    
    def convert_line(self, line, line_num=None, verbose=False):
        parts = line.strip().split()
        if not parts:
            return None
        # 检查字段数量
        if len(parts) != len(self.fields):
            err_msg = f"行 {line_num}: 字段数量不正确 - 期望 {len(self.fields)} 个，实际 {len(parts)} 个"
            
            # 尝试用制表符分割
            if '\t' in line:
                parts = line.strip().split('\t')
                if len(parts) != len(self.fields):
                    print(f"{err_msg} (尝试制表符分割后: {len(parts)} 个)")
                    return None
                else:
                    print(f"行 {line_num}: 使用制表符分割成功")
            else:
                print(err_msg)
                return None
        
        if verbose and line_num:
            print(f"\n转换第 {line_num} 行: {line.strip()}")
        
        # 解析每个字段
        field_values = []
        for i, part in enumerate(parts):
            # 获取期望的二进制位数
            expected_digits = self.fields[i].get("binary_digits")
            
            # 解析字段值
            value = self.parse_value(part, expected_digits)
            field_values.append(value)
            
            if verbose and line_num:
                print(f"  字段{i}({self.fields[i]['range']}): '{part}' -> {value} "
                      f"(0x{value:x}, 0b{value:b})")
        
        # 组合字段
        try:
            instruction = self.combine_fields(field_values, verbose)
            
            # 转换为54位二进制字符串
            binary_str = format(instruction, f'0{self.total_bits}b')
            
            return binary_str
            
        except Exception as e:
            print(f"行 {line_num}: 组合字段时出错 - {e}")
            return None
    
    def convert_file(self, input_file, output_file):
        instruction_count = 0
        error_count = 0
        try:
            with open(input_file, 'r') as f_in, open(output_file, 'w') as f_out:
                for line_num, line in enumerate(f_in, 1):
                    # 跳过空行和注释行
                    line_stripped = line.strip()
                    if not line_stripped:
                        continue
                    if line_stripped.startswith('#') or line_stripped.startswith('//'):
                        continue
                    
                    # 转换行
                    binary_str = self.convert_line(line_stripped, line_num)
                    
                    if binary_str is not None:
                        f_out.write(binary_str + '\n')
                        instruction_count += 1
                    else:
                        error_count += 1
                        print(f"第 {line_num} 行转换失败: {line_stripped}")
            
            return instruction_count, error_count
            
        except FileNotFoundError as e:
            print(f"错误: 找不到文件 {e.filename}")
            return 0, 1

def main():
    parser = argparse.ArgumentParser(formatter_class=argparse.RawDescriptionHelpFormatter)
    
    parser.add_argument('input_file', nargs='?')
    parser.add_argument('output_file', nargs='?')
    
    args = parser.parse_args()
    
    converter = InstructionConverter()
    
    print(f"开始转换: {args.input_file} -> {args.output_file}")
    
    count, errors = converter.convert_file(
        args.input_file, 
        args.output_file
    )
    
    if count > 0 or errors > 0:
        print(f"\n转换完成!")
        print(f"  成功转换: {count} 条指令")
        print(f"  转换失败: {errors} 行")
        print(f"  输出文件: {args.output_file}")
    else:
        print("转换失败")

if __name__ == "__main__":
    main()
