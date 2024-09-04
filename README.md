# 테라폼 클라우드
- 테라폼 클라우드에서 프로젝트를 생성한 후에 workspace를 직접 생성해줍니다
- 그리고 workspace의 실행모드를 remote모드가 아닌 local모드로 변경합니다.
- `terraform init`시 작성하는 oragnization은 테라폼 클라우드에서 project이름으로 작성해주세요.

# 도커 볼륨
- 도커 볼륨의 경우 수동으로 볼륨을 생성하여 volume id를 `TF_VAR_server_docker_volume_id` 환경변수로 지정해야 합니다.

# Server Pem Key
- server pem key의 경우에는 Secrets Manager에 생성되어 있습니다.

# Mysql
- mysql의 계정 정보는 secret manager에 있습니다.
- 보안 암호 이름 `caitory_mysql_account`
- s3 `caitory-mysql-backup`에 2024-09-05 백업 데이터가 담겨있습니다.