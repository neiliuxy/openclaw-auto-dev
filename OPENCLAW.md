# OpenClaw Project Config

- repo: neiliuxy/openclaw-auto-dev
- default_branch: master
- build_cmd: mkdir -p build && cd build && cmake .. && make
- test_cmd: cd build && ctest
- languages: [cpp]
