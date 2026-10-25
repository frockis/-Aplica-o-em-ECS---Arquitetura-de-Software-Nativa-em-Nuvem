#!/usr/bin/env bash
# Inventário dos recursos DESTA entrega (Fargate, Aurora, ALB, CloudFront, NAT).
#
# Não apaga nada. Só lista o que ainda existe e, quando faz sentido,
# imprime o comando para você mesmo desligar.
#
# Rode no AWS CloudShell (o script é bash; no PowerShell do Windows ele não roda):
#   bash verificar-recursos-entrega.sh
#   bash verificar-recursos-entrega.sh us-east-1

set -uo pipefail

REGION="${1:-}"
if [[ -z "$REGION" ]]; then
  REGION=$(aws configure get region 2>/dev/null || true)
fi
if [[ -z "$REGION" ]]; then
  read -rp "Digite a região (use us-east-1): " REGION
fi

echo "======================================================"
echo "Região da aplicação: $REGION"
echo "======================================================"

echo
echo "-- Load Balancers (cobram por hora) --"
ALB=$(aws elbv2 describe-load-balancers --region "$REGION" \
  --query 'LoadBalancers[].[LoadBalancerName,Type,State.Code,LoadBalancerArn]' \
  --output text 2>/dev/null || true)
if [[ -z "$ALB" ]]; then
  echo "(nenhum)"
else
  echo "$ALB"
  echo "    Para remover, use o console: EC2 → Load Balancers → selecione → Delete."
  echo "    Apague o balanceador antes do target group."
fi

echo
echo "-- Target groups --"
TG=$(aws elbv2 describe-target-groups --region "$REGION" \
  --query 'TargetGroups[].[TargetGroupName,Protocol,Port]' \
  --output text 2>/dev/null || true)
if [[ -z "$TG" ]]; then
  echo "(nenhum)"
else
  echo "$TG"
fi

echo
echo "-- Clusters ECS --"
CLUSTERS=$(aws ecs list-clusters --region "$REGION" --query 'clusterArns[]' --output text 2>/dev/null || true)
if [[ -z "$CLUSTERS" || "$CLUSTERS" == "None" ]]; then
  echo "(nenhum)"
else
  for ARN in $CLUSTERS; do
    NOME="${ARN##*/}"
    echo "  cluster: $NOME"
    SERVICOS=$(aws ecs list-services --region "$REGION" --cluster "$NOME" --query 'serviceArns[]' --output text 2>/dev/null || true)
    if [[ -z "$SERVICOS" || "$SERVICOS" == "None" ]]; then
      echo "    (sem serviços)"
    else
      for SARN in $SERVICOS; do
        SNOME="${SARN##*/}"
        echo "    serviço: $SNOME"
        echo "      aws ecs update-service --region $REGION --cluster $NOME --service $SNOME --desired-count 0"
        echo "      aws ecs delete-service --region $REGION --cluster $NOME --service $SNOME --force"
      done
    fi
    echo "    Depois que não houver serviços:"
    echo "      aws ecs delete-cluster --region $REGION --cluster $NOME"
  done
fi

echo
echo "-- Clusters Aurora / RDS --"
DBS=$(aws rds describe-db-clusters --region "$REGION" \
  --query 'DBClusters[].[DBClusterIdentifier,Engine,Status]' \
  --output text 2>/dev/null || true)
if [[ -z "$DBS" ]]; then
  echo "(nenhum cluster)"
else
  echo "$DBS"
  echo "    Apague pelo console e DESMARQUE o snapshot final."
  echo "    O script antigo verificar-recursos.sh olha instância RDS comum;"
  echo "    Aurora aparece melhor neste comando de clusters."
fi

echo
echo "-- NAT Gateways (custo alto; esta entrega não precisa de NAT) --"
NATS=$(aws ec2 describe-nat-gateways --region "$REGION" \
  --query 'NatGateways[?State!=`deleted`].[NatGatewayId,State]' \
  --output text 2>/dev/null || true)
if [[ -z "$NATS" ]]; then
  echo "(nenhum)"
else
  echo "$NATS"
  echo "    aws ec2 delete-nat-gateway --region $REGION --nat-gateway-id ID_AQUI"
fi

echo
echo "-- CloudFront (global; cobra pouco no free tier, mas deixe desligado) --"
CF=$(aws cloudfront list-distributions \
  --query 'DistributionList.Items[].[Id,DomainName,Status,Enabled]' \
  --output text 2>/dev/null || true)
if [[ -z "$CF" || "$CF" == "None" ]]; then
  echo "(nenhuma distribuição)"
else
  echo "$CF"
  echo "    No console: CloudFront → Disable → espere Status = Deployed → Delete."
fi

echo
echo "-- Elastic IPs soltos --"
aws ec2 describe-addresses --region "$REGION" \
  --query 'Addresses[?AssociationId==null].[AllocationId,PublicIp]' \
  --output text 2>/dev/null || true

echo
echo "Se alguma lista acima não estiver vazia, ainda há algo que pode cobrar."
echo "Confira também o console Billing → Bills, no dia seguinte."
