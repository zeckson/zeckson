### Exec `/bin/bash` on pod first container
```shell script
kubectl exec $POD_NAME -n dev --stdin --tty -- /bin/bash
```

### Get first pod with label `#<label>`
```shell
export POD=$(kubectl -n dev get pods -l 'service.istio.io/canonical-name=#<label>' -o jsonpath='{.items[0].metadata.name}')
```