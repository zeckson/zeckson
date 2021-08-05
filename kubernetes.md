### Exec `/bin/bash` on pod first container
```shell script
kubectl exec $POD_NAME -n dev --stdin --tty -- /bin/bash
```
