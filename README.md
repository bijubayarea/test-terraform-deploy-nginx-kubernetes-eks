### Terraform is used to provison both EKS kubernetes Infrastructure & deploy Kubernetes app

Terraform is a free and open-source infrastructure as code (IAC) that can help to automate the deployment, configuration, and management of the remote servers. Terraform can manage both existing service providers and custom in-house solutions.

![1](https://github.com/bijubayarea/test-terraform-deploy-nginx-kubernetes-eks/blob/main/images/1.png)



This terraform github repo deploys simple nginx application in EKS cluster
* Create the Kubernetes deployment using "nginx" image with replicas=2 in node_group_one
* Create a service of type=LoadBalancer  to expose app for simple create external access
* initContainer of deployment used to manipulate /usr/share/nginx/html/index.html to display
* Welcome to  POD:\<pod-name\>    NODE:\<node-name\>    NAMESPACE:\<namespace\>   POD_IP:\<pod-ip\>


**Prerequisites:**

* EKS access
* Basic understanding of AWS, Terraform & Kubernetes
* GitHub Account

# Part 1: Terraform scripts for the Kubernetes cluster.

**Step 1:  Create `.tf` file for accessing EKS cluster tfstate**

* Create `providers.tf` file and add below content in it
  ```
  data "terraform_remote_state" "eks" {
    backend = "local"
  
    config = {
      path = "../test-terraform-eks-cluster/terraform.tfstate"
    }
  }
  ```
* Retrieve EKS cluster information
  ```
  provider "aws" {
    region = data.terraform_remote_state.eks.outputs.region
  }
  
  data "aws_eks_cluster" "cluster" {
    name = data.terraform_remote_state.eks.outputs.cluster_id
  }
  ```

**Step 2:  Create `.tf` file for storing Kubernetes provider**

* Create `providers.tf` file and add below content in it
  ```
  provider "kubernetes" {
    host                   = data.aws_eks_cluster.cluster.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args = [
        "eks",
        "get-token",
        "--cluster-name",
        data.aws_eks_cluster.cluster.name
      ]
    }
  }
  ```
 
**Step 2:  Create `.tf` file for K8s deployment : NGINX webserver** 

* Create `k8s-deployment.tf` file for VPC and add below content in it
* Below in yaml format for easier readabilty (But terraform code used to deploy)

  ```
  spec:
      initContainers:
      - name: nginx-init        
        image: busybox:1.28
		    
        env:
        - name: MY_NODE_NAME
          valueFrom:
            fieldRef:
              apiVersion: v1
              fieldPath: spec.nodeName
        - name: MY_POD_NAME
          valueFrom:
            fieldRef:
              apiVersion: v1
              fieldPath: metadata.name
        - name: MY_POD_NAMESPACE
          valueFrom:
            fieldRef:
              apiVersion: v1
              fieldPath: metadata.namespace
        - name: MY_POD_IP
          valueFrom:
            fieldRef:
              apiVersion: v1
              fieldPath: status.podIP
        command:
        - sh
        - -c
        - echo Welcome to POD:$(MY_POD_NAME) NODE:$(MY_NODE_NAME) NAMESPACE:$(MY_POD_NAMESPACE)
          POD_IP:$(MY_POD_IP)> /work-dir/index.html
        
        volumeMounts:
        - mountPath: /work-dir
          mountPropagation: None
          name: workdir
  ```
* create k8s deployment "nginx" with replicas=2
* pod containers: one is initContainer=nginx-init and container=nginx-pod-node
* intContainer used to get environment variables: POD_NAME and NODE_NAME and write to /usr/share/nginx/html/index.html
* pod ephemeral volume EmptyDir is attached to pod and mounted on both containers 

  ```
  containers:
      - name: nginx-pod-node
        image: nginx:1.7.8
        ports:
        - containerPort: 80
          protocol: TCP
        resources:
          limits:
            cpu: 500m
            memory: 512Mi
          requests:
            cpu: 250m
            memory: 50Mi
        volumeMounts:
        - mountPath: /usr/share/nginx/html
          mountPropagation: None
          name: workdir
      
      volumes:
      - emptyDir: {}
        name: workdir
  ```

**Step 4: Create .tf file to expose k8s deploy as service=Loadbalancer**

* Create `k8s-service.tf` file for k8s service and add below content in it
* Below in yaml format for easier readabilty (But terraform code used to deploy)

  ```
  apiVersion: v1
  kind: Service
  metadata:
    name: nginx-service
  spec:
    ports:
    - nodePort: 31754
      port: 80
      protocol: TCP
      targetPort: 80
    selector:
      App: nginx-pod-node
    type: LoadBalancer
  ```
  

**Step 5: Create .tf file for outputs for K8s LoadBalancer**

* Create `outputs.tf` file and add below content in it

  ```
  output "lb_ip" {
    value = kubernetes_service.nginx.status.0.load_balancer.0.ingress.0.hostname
  }

  ```
* output the name of the LoadBalancer.


**Step 6: Store our code to GitHub Repository**

* store the code in the GitHub repository

![2](https://github.com/bijubayarea/test-terraform-deploy-nginx-kubernetes-eks/blob/main/images/2.png)

**Step 9: Initialize the working directory**

* Run `terraform init` command in the working directory. It will download all the necessary providers and all the modules

**Step 10: Create a terraform plan**

* Run `terraform plan` command in the working directory. It will give the execution plan

  ```
  Plan: 6 to add, 0 to change, 0 to destroy.
  Changes to Outputs:
  + lb_ip           = (known after apply)

  ```


**Step 11: Create the k8s app & service on EKS**

* Run `terraform apply` command in the working directory. It will be going to create the Kubernetes cluster on AWS
* Terraform will create the below resources on AWS

* k8s deployment
* k8s service


**Step 12: Check output of terraform apply**

* Output for `terraform plan` command 

  ```
  $ terraform output
  lb_ip = "ac32240ec0119446cbbad59de348fd7e-2131601910.us-west-2.elb.amazonaws.com"

  ```

**Step 12: Set kubeconfig to access EKS kubernetes cluster using kubectl**

* retrieve the access credentials for your cluster from output and configure kubectl

  ```
  aws eks --region $(terraform output -raw region) update-kubeconfig \
    --name $(terraform output -raw cluster_name)

  ```


**Step 13: Verify the resources on AWS**

* Navigate to your AWS account and verify the resources

1. k8s deployment:
  ```
  ```
![3](https://github.com/bijubayarea/test-terraform-deploy-nginx-kubernetes-eks/blob/main/images/3.png)

2. k8s service=LoadBalancer:
   ```
   ```
![4](https://github.com/bijubayarea/test-terraform-deploy-nginx-kubernetes-eks/blob/main/images/4.png)


* Kubernetes cluster is ready 
* Verify access to NGINX application using browser or 'curl' command


**Step 12: Access NGINX using 'curl' & browser**

* retrieve the access credentials for your cluster from output and configure kubectl

  ```
  $ curl -s ac32240ec0119446cbbad59de348fd7e-2131601910.us-west-2.elb.amazonaws.com
  Welcome to POD:nginx-b4988fd99-pk2cz NODE:ip-10-0-2-251.us-west-2.compute.internal NAMESPACE:default POD_IP:10.0.2.90
  
  $ curl -s ac32240ec0119446cbbad59de348fd7e-2131601910.us-west-2.elb.amazonaws.com
  Welcome to POD:nginx-b4988fd99-5hvj8 NODE:ip-10-0-1-118.us-west-2.compute.internal NAMESPACE:default POD_IP:10.0.1.100
  
  $ curl -s ac32240ec0119446cbbad59de348fd7e-2131601910.us-west-2.elb.amazonaws.com
  Welcome to POD:nginx-b4988fd99-pk2cz NODE:ip-10-0-2-251.us-west-2.compute.internal NAMESPACE:default POD_IP:10.0.2.90
  
  $ curl -s ac32240ec0119446cbbad59de348fd7e-2131601910.us-west-2.elb.amazonaws.com
  Welcome to POD:nginx-b4988fd99-pk2cz NODE:ip-10-0-2-251.us-west-2.compute.internal NAMESPACE:default POD_IP:10.0.2.90
  
  $ curl -s ac32240ec0119446cbbad59de348fd7e-2131601910.us-west-2.elb.amazonaws.com
  Welcome to POD:nginx-b4988fd99-pk2cz NODE:ip-10-0-2-251.us-west-2.compute.internal NAMESPACE:default POD_IP:10.0.2.90
  
  $ curl -s ac32240ec0119446cbbad59de348fd7e-2131601910.us-west-2.elb.amazonaws.com
  Welcome to POD:nginx-b4988fd99-5hvj8 NODE:ip-10-0-1-118.us-west-2.compute.internal NAMESPACE:default POD_IP:10.0.1.100

  ```
  ![5](https://github.com/bijubayarea/test-terraform-deploy-nginx-kubernetes-eks/blob/main/images/5.png)
