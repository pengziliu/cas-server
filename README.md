# 单点登陆服务端搭建教程
>单点登录是企业业务整合比较流行解决方案，像多个系统使用同一个用户数据库的，并且这些系统需要相互信任时，此时使用单点登陆(SSO)是比较合适的。


#cas简介
CAS 是Yale（耶鲁）大学的一个开源的企业级单点登录系统，它的特点：

- Java (Spring Webflow/Spring Boot) 服务组件
- 可插拔身份验证支持（LDAP，Database，X.509，MFA）
- 支持多种协议（CAS，SAML，OAuth，OpenID，OIDC）
- 跨平台客户端支持（Java，.Net，PHP，Perl，Apache等）
- 与uPortal，Liferay，BlueSocket，Moodle，Google Apps等集成

cas server: https://github.com/Jasig/cas/releases 
cas client: http://developer.jasig.org/cas-clients/ 
CAS官网地址：http://www.jasig.org/cas

>cas服务端需要单独部署，本篇主要为服务端教程，主要围绕环境、本地构建、改造以及运行和调试，Cas项目一直有团队在维护，新的版本都已经集成了springboot和cloud,减少尽可能的xml配置以及可配合pringCloud集成高可用

### cas原理和流程
![](http://owk82a6fs.bkt.clouddn.com/2018-07-11-15308615111101.jpg)
（截图来源网络）
>- 1.用户通过browser请求cas client A端的资源。
- 2.client A端发现用户未登录(client没有收到ST)，redirect到cas server，并且把用户请求服务的url发送给server；server发现用户浏览器中没有TGC(Ticket Granting Cookie)，就跳转到登录页面。
- 3.用户在登录页面登录并登录成功。
- 4.server在用户的浏览器中设置一个TGC(Ticket Granting Cookie)，并且在server端保存一个TGT(Ticket Granting Tciket)，然后把用户重定向到{client A网址+ST(Service Ticket)}，其中ST是由TGT生成的。
- 5.client A端通过GET的方法收到ST，向server端验证这个ticket的有效性，这一步主要是为了防止恶意用{client网址+杜撰的ST}来访问client A，所以虽然ST是server发送给client A的，client A仍然需要向server验证其有效性。
- 6.ticket有效，server端返回ticket对应的用户的用户名，client A端为用户提供请求的服务。

上述是未登录的用户访问client A的过程，用户通过以上步骤已经登录了CAS系统，此时他访问CAS系统中信任的client B端，是不用登录的，实现步骤如下：
>- 1.1.用户通过browser请求cas client B端的资源。
- 2.client B端发现没有收到ST，redirect到cas server，并且把用户请求服务的url发送给server；server发现用户浏览器中有TGC(Ticket Granting Cookie)，验证该TGC后，用server端存储的TGT生成一个ST。
- 3.server把用户重定向到{client B网址+ST(Service Ticket)}。
- 4.client B端通过GET的方法收到ST，向server端验证这个ticket的有效性.
- 5.ticket有效，server端返回ticket对应的用户的用户名，client B端为用户提供请求的服务，这样用户就不用再次登录就可以访问到client B了。

所以从上述过程中，可以看到client端既不能接触到用户的用户名密码，也不能接触到用户的凭证TGT或者TGC，它只做两件事情：如果用户的请求里有ST，那么就向服务器验证ST的有效性；如果用户的请求里没有ST，那么就把用户重定向到cas server；

cas server全权负责管理用户的用户名和密码，如果发现用户的浏览器里面有有效的TGC，就生成ST把用户重定向到client端；如果用户浏览器里面没有TGC或者TGC无效，就让用户重新登录，然后在用户的浏览器里面设置新的TGC。而server和用户浏览器之间的交互是https安全协议，这样就保证了用户的用户名密码的安全性。 

### 环境相关
- Jdk 1.8
- Maven 3.3
- IntelliJ IDEA
- Apache-tomcat-8.5.32

###下载代码
下载的是maven版本的
```
git clone https://github.com/apereo/cas-overlay-template.git
```
![1530686594284](http://owk82a6fs.bkt.clouddn.com/2018-07-11-1530686594284.jpg)
下载完成以后查看目录结构，发现并无java代码，而是一些配置文件和脚本文件，所以我们需要对其进行构建和打包
### 导入项目到idea

![1530691317549](http://owk82a6fs.bkt.clouddn.com/2018-07-11-1530691317549.jpg)

如图，导入完以后，开始下载war包了。网速快的话很快就下好了。然后在插件中执行install 命令 或在目录中执行maven命令，生成war包
![1530693509090](http://owk82a6fs.bkt.clouddn.com/2018-07-11-1530693509090.jpg)

### 项目初运行
添加tomcat服务器运行项目，如图
![1530860466469](http://owk82a6fs.bkt.clouddn.com/2018-07-11-1530860466469.jpg)
![1530860554984](http://owk82a6fs.bkt.clouddn.com/2018-07-11-1530860554984.jpg)
然后开始运行项目就跑起来了。登录界面长这样，![](http://owk82a6fs.bkt.clouddn.com/2018-07-11-15308607062274.jpg)
页面访问是很慢的，因为在线引入了很多外部网站的css、js等文件。我们后面改造成引入本地的，将极大提升效率
**登录成功界面**
![](http://owk82a6fs.bkt.clouddn.com/2018-07-11-15308621961272.jpg)
登录用户和密码为打包后的`application.properties`的cas.authn.accept.users=用户名::密码 属性，如果此属性开启，为默认的用户名密码。当然，也可以扩展成我们自己的数据库验证方式。

##项目改造
改造的话按照一般基本要求打算以以下几点进行开展，基本满足大部分要求:
 
 - 项目结构调整(便于二次开发)
 - 登录验证 (数据库登录、密码加密方式)
 - 自定义页面 (个性化定制)
 - 远程资源本地化 (满足内网访问、提升访问速度)
 - 票据持久化(分布式、高可用)
 - 分布式集群

### 项目结构调整
默认的项目结构是这样的
![](http://owk82a6fs.bkt.clouddn.com/2018-07-11-15308639425552.jpg)
基本是为了构建打包服务和运行。下载到本地构建后查看target目录，它的结构是这样的
![](http://owk82a6fs.bkt.clouddn.com/2018-07-11-15308640513334.jpg)
当然，这些东西都是项目的依赖产生的。所以为了方便二次开发，我们项目结构改造后成这样
![](http://owk82a6fs.bkt.clouddn.com/2018-07-11-15308642592634.jpg)
是不是跟spring boot 结构差不多呢？这个结构是根据它的target决定的，我们构建打包的时候能够去覆盖它原始的，当然，pom.xml需要这么配。
在build节点加入这段
```java
  <resources>
            <resource>
                <directory>src/main/resources</directory>
                <includes>
                    <include>**/*</include>
                </includes>
            </resource>
        </resources>      
```
除了这点，还整理了pom.xml，去除很多不需要的配置，加入需要的配置。具体见整理后的源码。

## git地址：https://github.com/pengziliu/cas-server.git
后续会就相关点进行改造，欢迎关注。
####改造相关
 - 项目结构调整(便于二次开发)
 - 登录验证 (数据库登录、密码加密方式)
 - 自定义页面 (个性化定制)
 - 远程资源本地化 (满足内网访问、提升访问速度)
 - 票据持久化(分布式、高可用)
 - 分布式集群
 - 客户端集成






CAS Overlay Template
============================

Generic CAS WAR overlay to exercise the latest versions of CAS. This overlay could be freely used as a starting template for local CAS war overlays. The CAS services management overlay is available [here](https://github.com/apereo/cas-services-management-overlay).

# Versions

```xml
<cas.version>5.3.x</cas.version>
```

# Requirements

* JDK 1.8+

# Configuration

The `etc` directory contains the configuration files and directories that need to be copied to `/etc/cas/config`.

# Build

To see what commands are available to the build script, run:

```bash
./build.sh help
```

To package the final web application, run:

```bash
./build.sh package
```

To update `SNAPSHOT` versions run:

```bash
./build.sh package -U
```

# Deployment

- Create a keystore file `thekeystore` under `/etc/cas`. Use the password `changeit` for both the keystore and the key/certificate entries.
- Ensure the keystore is loaded up with keys and certificates of the server.

On a successful deployment via the following methods, CAS will be available at:

* `http://cas.server.name:8080/cas`
* `https://cas.server.name:8443/cas`

## Executable WAR

Run the CAS web application as an executable WAR.

```bash
./build.sh run
```

## Spring Boot

Run the CAS web application as an executable WAR via Spring Boot. This is most useful during development and testing.

```bash
./build.sh bootrun
```

### Warning!

Be careful with this method of deployment. `bootRun` is not designed to work with already executable WAR artifacts such that CAS server web application. YMMV. Today, uses of this mode ONLY work when there is **NO OTHER** dependency added to the build script and the `cas-server-webapp` is the only present module. See [this issue](https://github.com/spring-projects/spring-boot/issues/8320) for more info.


## Spring Boot App Server Selection

There is an app.server property in the `pom.xml` that can be used to select a spring boot application server.
It defaults to `-tomcat` but `-jetty` and `-undertow` are supported.

It can also be set to an empty value (nothing) if you want to deploy CAS to an external application server of your choice.

```xml
<app.server>-tomcat<app.server>
```

## Windows Build

If you are building on windows, try `build.cmd` instead of `build.sh`. Arguments are similar but for usage, run:

```
build.cmd help
```

## External

Deploy resultant `target/cas.war`  to a servlet container of choice.


## Command Line Shell

Invokes the CAS Command Line Shell. For a list of commands either use no arguments or use `-h`. To enter the interactive shell use `-sh`.

```bash
./build.sh cli
```# cas-server
