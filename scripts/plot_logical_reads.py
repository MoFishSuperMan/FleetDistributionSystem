import matplotlib.pyplot as plt
import numpy as np

# ================= 配置部分 =================
# 1. 设置中文字体 (优先尝试常见的中文字体，防止乱码)
plt.rcParams['font.sans-serif'] = ['SimHei', 'Microsoft YaHei', 'Arial Unicode MS', 'SimSun'] 
plt.rcParams['axes.unicode_minus'] = False  # 解决负号显示为方块的问题

# 2. 数据准备
# 使用中文标签
scenarios = ['范围查询\n(时间)', '精确查找\n(司机)', '排序\n(异常记录)', '状态过滤\n(Pending订单)']
reads_before = [2005, 2005, 1954, 2005] # 无索引
reads_after = [6, 3, 62, 157]           # 有索引

x = np.arange(len(scenarios))
width = 0.35

# 3. 创建图表
fig, ax = plt.subplots(figsize=(10, 6))

# 绘制柱状图
rects1 = ax.bar(x - width/2, reads_before, width, label='无索引 (全表扫描)', color='#ff9999', alpha=0.9)
rects2 = ax.bar(x + width/2, reads_after, width, label='有索引 (索引查找)', color='#66b3ff', alpha=0.9)

# 4. 设置标签和标题
ax.set_ylabel('逻辑读取次数 (页) - 对数坐标')
ax.set_title('数据库索引性能优化对比 (数值越低越好)', fontsize=14, pad=15)
ax.set_xticks(x)
ax.set_xticklabels(scenarios, fontsize=11)

# 设置对数坐标，否则差异太大看不清
ax.set_yscale('log')

# === 关键修复：设置 Y 轴范围，防止顶部数字被遮挡 ===
# 这里的 5000 是根据最大值 2005 调整的，给上方留出空间
ax.set_ylim(1, 5000) 

# 5. 设置图例 (放在右上角，避免遮挡数据)
ax.legend(loc='upper right', frameon=True, fontsize=10)

# 6. 自动标注数值函数
def autolabel(rects):
    for rect in rects:
        height = rect.get_height()
        # xytext=(0, 3) 表示文字在柱子上方偏移 3 个点
        ax.annotate('{}'.format(height),
                    xy=(rect.get_x() + rect.get_width() / 2, height),
                    xytext=(0, 5), 
                    textcoords="offset points",
                    ha='center', va='bottom', fontsize=11, fontweight='bold')

autolabel(rects1)
autolabel(rects2)

plt.tight_layout()

# 保存图片
print("正在生成图片...")
plt.savefig('index_performance_cn.png', dpi=300)
print("已保存为 'index_performance_cn.png'")