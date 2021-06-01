
#doctl kubernetes cluster kubeconfig remove ${kube-id}

doctl auth init
doctl kubernetes cluster kubeconfig save ${kube-id}
