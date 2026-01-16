
运行项目
----
本项目使用 [uv](https://github.com/astral-sh/uv) 进行依赖管理和环境配置，如果不想使用 uv，也可以用 venv conda 等手动创建虚拟环境并安装依赖，Django, pymssql 等依赖可以从 `pyproject.toml` 中查看并安装。

1. 配置环境与安装依赖：

确保已安装 `uv`，然后在项目根目录下运行：

```powershell
# if you don't install uv before
pip install uv
```

```powershell
git clone https://github.com/MoFishSuperMan/FleetDistributionSystem
cd FleetDistributionSystem
uv sync
```

2. 配置数据库连接

在 `apps/models.py` 中，请根据你的数据库服务器名、数据库名、用户名和密码调整连接参数。例如：

```python
conn = pymssql.connect(
		server='YOUR_SERVER',
		user='YOUR_USER',         # 可选
		password='YOUR_PASSWORD', # 可选
		database='YOUR_DATABASE',
)
```

注意：若使用 Windows 身份验证或不同驱动，连接参数会有所变化。