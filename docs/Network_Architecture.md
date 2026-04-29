# PlantUMLを使ったネットワーク図
```
@startuml
!include <aws/common>
!include <aws/NetworkingContentDelivery/AmazonVPC>
!include <aws/NetworkingContentDelivery/AmazonRoute53>
!include <aws/Compute/AmazonEC2>
!include <aws/Database/AmazonRDS>
!include <aws/NetworkingContentDelivery/AmazonELBApplicationLoadBalancer>
!include <aws/NetworkingContentDelivery/AmazonNATGateway>
!include <aws/NetworkingContentDelivery/AmazonInternetGateway>

skinparam linetype ortho

frame "sample-vpc (10.0.0.0/16)" {
    AmazonInternetGateway(igw, "Internet Gateway", " ")

    rectangle "Availability Zone: 1a" as az1a {
        rectangle "Public Subnet (10.0.1.0/24)" as pub1a {
            AmazonELBApplicationLoadBalancer(alb, "ALB", "Load Balancer")
            AmazonNATGateway(nat1, "NAT Gateway 01", " ")
        }
        rectangle "Private Subnet (10.0.10.0/24)" as priv1a {
            AmazonEC2(web1, "WebServer 01", "Ubuntu")
        }
        rectangle "DB Subnet (10.0.128.0/24)" as db1a {
            AmazonRDS(db_master, "DB Master", "Primary")
        }
    }

    rectangle "Availability Zone: 1c" as az1c {
        rectangle "Public Subnet (10.0.2.0/24)" as pub1c {
            AmazonEC2(bastion, "Bastion", "Jump Host")
            AmazonNATGateway(nat2, "NAT Gateway 02", " ")
        }
        rectangle "Private Subnet (10.0.20.0/24)" as priv1c {
            AmazonEC2(web2, "WebServer 02", "Ubuntu")
        }
        rectangle "DB Subnet (10.0.144.0/24)" as db1c {
            AmazonRDS(db_standby, "DB Standby", "Secondary")
        }
    }
}

' 通信の定義
actor User
User --> igw
igw --> alb : Port 80/443
igw --> bastion : SSH (Port 22)

bastion -[#blue]-> web1 : SSH
bastion -[#blue]-> web2 : SSH

alb --> web1 : HTTP
alb --> web2 : HTTP

web1 --> db_master
web2 --> db_master
db_master <-> db_standby : Multi-AZ Sync

@enduml
```
