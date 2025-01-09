import os
from git import Repo

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
        f.write("</head>\n")
        f.write("<body>\n")
        f.write("    <h1>目录结构</h1>\n")
        f.write("    <ul>\n")

        # 递归遍历目录
        def write_directory_tree(directory, indent_level=0):
            # 遍历当前目录
            for item in sorted(os.listdir(directory)):
                full_path = os.path.join(directory, item)
                # 检查是否在排除列表中
                if item in exclude_dirs:
                    continue

                # 如果是目录，递归处理
                if os.path.isdir(full_path):
                    f.write(f"{'    ' * (indent_level + 1)}<li><strong>{item}/</strong></li>\n")
                    f.write(f"{'    ' * (indent_level + 1)}<ul>\n")
                    write_directory_tree(full_path, indent_level + 1)
                    f.write(f"{'    ' * (indent_level + 1)}</ul>\n")
                # 如果是文件，生成超链接并添加 Git 提交信息作为工具提示
                else:
                    file_url = full_path.replace("\\", "/")  # 处理 Windows 路径
                    commit_message = get_git_commit_message(full_path)  # 获取提交信息
                    f.write(f"{'    ' * (indent_level + 1)}<li><a href='{file_url}' title='{commit_message}'>{item}</a></li>\n")

        # 开始遍历
        write_directory_tree(path)

        # 写入 HTML 尾部
        f.write("    </ul>\n")
        f.write("</body>\n")
        f.write("</html>\n")

    print(f"目录结构已生成到文件: {output_file}")

if __name__ == '__main__':
    # 指定不生成的目录
    exclude_directories = ['.idea', '.git']  # 修改为你想要排除的目录名
    # 调用函数生成目录结构 HTML 文件
    generate_directory_tree_html("./", 'index.html', exclude_dirs=exclude_directories)
