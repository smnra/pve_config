import os
from git import Repo
from datetime import datetime

def get_git_commit_message(file_path):
    """获取给定文件的最新 Git 提交信息"""
    try:
        # 获取当前仓库
        repo = Repo(os.getcwd(), search_parent_directories=True)
        # 获取文件的提交历史
        commits = list(repo.iter_commits(paths=file_path, max_count=1))
        if commits:
            return commits[0].message.strip()  # 返回最新提交信息
        else:
            return "无提交信息"
    except Exception as e:
        return f"错误: {str(e)}"

def generate_directory_tree_html(path, output_file="index.html", exclude_dirs=None):
    # 默认不生成的目录列表
    if exclude_dirs is None:
        exclude_dirs = []

    if os.path.exists(output_file):
        os.remove(output_file)  # 删除已存在的 index.html 文件

    # 打开文件准备写入
    with open(output_file, "w", encoding="utf-8") as f:
        # 写入 HTML 头部
        f.write("<!DOCTYPE html>\n")
        f.write("<html lang='zh-CN'>\n")
        f.write("<head>\n")
        f.write("    <meta charset='UTF-8'>\n")
        f.write("    <title>目录结构</title>\n")
        f.write("    <style>\n")
        f.write("        body { margin: 0; padding: 20px; font-family: Arial, sans-serif; background-color: #f4f4f4; color: #333; }\n")
        f.write("        h1 { text-align: center; color: #0066cc; }\n")
        f.write("        .file-link { color: #007bff; text-decoration: none; transition: color 0.3s; }\n")
        f.write("        .file-link:hover { color: #0056b3; text-decoration: underline; }\n")
        f.write("        .modify-time { color: gray; font-size: smaller; }\n")
        f.write("        .directory { list-style-type: circle; }\n")  # 目录项目符号为空心圆
        f.write("        .file { list-style-type: disc; }\n")  # 文件项目符号为实心圆
        f.write("        .toggle-buttons { margin-bottom: 10px; text-align: center; }\n")
        f.write("        .toggle-buttons button { margin: 0 5px; padding: 10px 15px; border: none; border-radius: 5px; background-color: #007bff; color: white; cursor: pointer; transition: background-color 0.3s; }\n")
        f.write("        .toggle-buttons button:hover { background-color: #0056b3; }\n")
        f.write("        #back-to-top {\n")  # 回到顶部按钮样式
        f.write("            position: fixed;\n")
        f.write("            bottom: 20px;\n")
        f.write("            right: 20px;\n")
        f.write("            background-color: #007bff;\n")
        f.write("            color: white;\n")
        f.write("            border: none;\n")
        f.write("            border-radius: 50%;\n")
        f.write("            width: 40px;\n")
        f.write("            height: 40px;\n")
        f.write("            font-size: 18px;\n")
        f.write("            cursor: pointer;\n")
        f.write("            box-shadow: 0 2px 5px rgba(0, 0, 0, 0.2);\n")
        f.write("            display: none; /* 默认隐藏 */\n")
        f.write("            transition: background-color 0.3s;\n")
        f.write("        }\n")
        f.write("        #back-to-top:hover {\n")
        f.write("            background-color: #0056b3;\n")
        f.write("        }\n")
        f.write("        /* 防止内容换行，添加水平滚动条 */\n")
        f.write("        ul { white-space: nowrap; }\n")  # 禁止换行
        f.write("        li { white-space: nowrap; }\n")  # 禁止换行
        f.write("        body { overflow-x: auto; }\n")  # 添加水平滚动条
        f.write("        .container { max-width: 1200px; margin: auto; padding: 20px; background: white; box-shadow: 0 4px 8px rgba(0, 0, 0, 0.1); border-radius: 10px; }\n")
        f.write("    </style>\n")
        f.write("    <script>\n")
        f.write("        function expandAll() {\n")
        f.write("            const details = document.querySelectorAll('details');\n")
        f.write("            details.forEach(detail => detail.open = true);\n")
        f.write("        }\n")
        f.write("        function collapseAll() {\n")
        f.write("            const details = document.querySelectorAll('details');\n")
        f.write("            details.forEach(detail => detail.open = false);\n")
        f.write("        }\n")
        f.write("        // 回到顶部功能\n")
        f.write("        window.onscroll = function() {\n")
        f.write("            const backToTopButton = document.getElementById('back-to-top');\n")
        f.write("            if (document.body.scrollTop > 20 || document.documentElement.scrollTop > 20) {\n")
        f.write("                backToTopButton.style.display = 'block';\n")
        f.write("            } else {\n")
        f.write("                backToTopButton.style.display = 'none';\n")
        f.write("            }\n")
        f.write("        };\n")
        f.write("        function scrollToTop() {\n")
        f.write("            document.body.scrollTop = 0; // 兼容 Safari\n")
        f.write("            document.documentElement.scrollTop = 0; // 兼容 Chrome, Firefox, IE, Opera\n")
        f.write("        }\n")
        f.write("    </script>\n")
        f.write("</head>\n")
        f.write("<body>\n")
        f.write("    <div class='container'>\n")  # 添加容器以美化外观
        f.write("        <h1>目录结构</h1>\n")
        f.write("        <div class='toggle-buttons'>\n")
        f.write("            <button onclick='expandAll()'>一键展开</button>\n")
        f.write("            <button onclick='collapseAll()'>一键收起</button>\n")
        f.write("        </div>\n")
        f.write("        <ul>\n")

        # 递归遍历目录
        def write_directory_tree(directory, indent_level=0):
            # 遍历当前目录
            for item in sorted(os.listdir(directory)):
                full_path = os.path.join(directory, item)
                # 检查是否在排除列表中
                if item in exclude_dirs:
                    continue

                # 如果是目录，使用 <details> 和 <summary> 实现收起/展开功能
                if os.path.isdir(full_path):
                    f.write(f"{'    ' * (indent_level + 1)}<li class='directory'>\n")
                    f.write(f"{'    ' * (indent_level + 1)}<details>\n")
                    f.write(f"{'    ' * (indent_level + 2)}<summary><strong>{item}/</strong></summary>\n")
                    f.write(f"{'    ' * (indent_level + 2)}<ul>\n")
                    write_directory_tree(full_path, indent_level + 1)  # 递归处理子目录
                    f.write(f"{'    ' * (indent_level + 2)}</ul>\n")
                    f.write(f"{'    ' * (indent_level + 1)}</details>\n")
                    f.write(f"{'    ' * (indent_level + 1)}</li>\n")
                # 如果是文件，生成超链接并添加 Git 提交信息作为工具提示
                else:
                    file_url = full_path.replace("\\", "/")  # 处理 Windows 路径
                    commit_message = get_git_commit_message(full_path)  # 获取提交信息
                    # 获取文件的修改时间
                    modify_time = datetime.fromtimestamp(os.path.getmtime(full_path)).strftime('%Y-%m-%d %H:%M:%S')
                    # 在文件名后显示修改时间，添加分隔符和样式
                    f.write(f"{'    ' * (indent_level + 1)}<li class='file'><a class='file-link' href='{file_url}' title='{commit_message}'>{item}</a> <span class='modify-time'>------- (修改时间: {modify_time})</span></li>\n")

        # 开始遍历
        write_directory_tree(path)

        # 写入 HTML 尾部
        f.write("        </ul>\n")
        f.write("        <button id='back-to-top' onclick='scrollToTop()' title='回到顶部'>↑</button>\n")  # 回到顶部按钮
        f.write("    </div>\n")  # 关闭容器 div
        f.write("</body>\n")
        f.write("</html>\n")

    print(f"目录结构已生成到文件: {output_file}")

if __name__ == '__main__':
    # 指定不生成的目录
    exclude_directories = ['.idea', '.git']  # 修改为你想要排除的目录名
    # 调用函数生成目录结构 HTML 文件
    generate_directory_tree_html("./", 'index.html', exclude_dirs=exclude_directories)
