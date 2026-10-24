#!/bin/bash
# 第 4 步：用 PyYAML 檢查 workflow 語法，並印出 jobs／steps 結構
set -eo pipefail
python3 -c "import yaml; print('PyYAML', yaml.__version__)"
python3 -c "
import yaml, sys
path = '.github/workflows/ros2-ci.yml'
try:
    with open(path, encoding='utf-8') as f:
        doc = yaml.safe_load(f)
except yaml.YAMLError as e:
    print('YAML 語法錯誤：', e); sys.exit(1)
# PyYAML 依 YAML 1.1 會把 on 解析成布林 True，GitHub 不受影響
triggers = doc.get('on', doc.get(True))
print('name:', doc['name'])
print('triggers:', list(triggers))
for job, spec in doc['jobs'].items():
    print(f'job {job}: runs-on={spec[\"runs-on\"]}, needs={spec.get(\"needs\")}')
    for s in spec['steps']:
        print('   -', s.get('uses') or s.get('name'))
print('YAML_OK')
"
