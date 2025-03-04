// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract AppVersionContract {
    // 应用信息结构体
    struct AppInfo {
        string version; // 版本号
        string downloadLink; // 下载链接
        string updateContent; // 更新内容
    }

    // 节点信息结构体
    struct NodeInfo {
        string url; // 节点网址
        address addedBy; // 添加者地址
        uint256 addedTime; // 添加时间
        bool isApproved; // 是否已批准
    }

    // 存储APP信息
    AppInfo private appInfo;

    // 存储已批准的节点网址列表
    string[] private approvedNodeUrls;

    // 存储待审核的节点网址列表
    string[] private pendingNodeUrls;

    // 存储所有节点信息
    mapping(string => NodeInfo) private nodes;

    // 节点网址是否存在
    mapping(string => bool) private nodeUrlExists;

    // 合约拥有者地址
    address private owner;

    // 节点管理员列表
    mapping(address => bool) private nodeManagers;

    // 事件：更新应用信息时触发
    event AppInfoUpdated(
        string version,
        string downloadLink,
        string updateContent
    );

    // 事件：添加节点网址时触发
    event NodeUrlAdded(
        string nodeUrl,
        address indexed addedBy,
        bool isApproved
    );

    // 事件：节点状态更改时触发
    event NodeStatusChanged(string nodeUrl, bool isApproved);

    // 事件：删除节点网址时触发
    event NodeUrlRemoved(string nodeUrl);

    // 事件：添加节点管理员时触发
    event NodeManagerAdded(address indexed manager);

    // 事件：移除节点管理员时触发
    event NodeManagerRemoved(address indexed manager);

    // 构造函数：设置合约拥有者
    constructor() {
        owner = msg.sender;
        nodeManagers[msg.sender] = true; // 合约部署者自动成为管理员
    }

    // 修饰符：只有合约拥有者才能调用
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    // 修饰符：只有节点管理员才能调用
    modifier onlyNodeManager() {
        require(
            nodeManagers[msg.sender] || msg.sender == owner,
            "Only node manager can call this function"
        );
        _;
    }

    // 更新应用信息
    function updateAppInfo(
        string calldata version,
        string calldata downloadLink,
        string calldata updateContent
    ) external onlyOwner {
        appInfo.version = version;
        appInfo.downloadLink = downloadLink;
        appInfo.updateContent = updateContent;

        emit AppInfoUpdated(version, downloadLink, updateContent);
    }

    // 获取完整应用信息
    function getAppInfo()
        external
        view
        returns (
            string memory version,
            string memory downloadLink,
            string memory updateContent
        )
    {
        return (appInfo.version, appInfo.downloadLink, appInfo.updateContent);
    }

    // 添加节点管理员
    function addNodeManager(address manager) external onlyOwner {
        require(!nodeManagers[manager], "Address is already a node manager");
        nodeManagers[manager] = true;
        emit NodeManagerAdded(manager);
    }

    // 移除节点管理员
    function removeNodeManager(address manager) external onlyOwner {
        require(nodeManagers[manager], "Address is not a node manager");
        require(manager != owner, "Cannot remove owner from node managers");
        nodeManagers[manager] = false;
        emit NodeManagerRemoved(manager);
    }

    // 检查是否是节点管理员
    function isNodeManager(address account) external view returns (bool) {
        return nodeManagers[account] || account == owner;
    }

    // 添加节点网址 - 任何人都可以调用
    function addNodeUrl(string calldata nodeUrl) external {
        require(bytes(nodeUrl).length > 0, "Node URL cannot be empty");
        require(!nodeUrlExists[nodeUrl], "Node URL already exists");

        // 如果是管理员，直接批准节点
        bool isApproved = nodeManagers[msg.sender] || msg.sender == owner;

        // 创建新的节点信息
        NodeInfo storage newNode = nodes[nodeUrl];
        newNode.url = nodeUrl;
        newNode.addedBy = msg.sender;
        newNode.addedTime = block.timestamp;
        newNode.isApproved = isApproved;

        // 添加到相应列表
        if (isApproved) {
            approvedNodeUrls.push(nodeUrl);
        } else {
            pendingNodeUrls.push(nodeUrl);
        }

        nodeUrlExists[nodeUrl] = true;

        emit NodeUrlAdded(nodeUrl, msg.sender, isApproved);
    }

    // 批准节点 - 仅管理员可以调用
    function approveNode(string memory nodeUrl) public onlyNodeManager {
        require(nodeUrlExists[nodeUrl], "Node URL does not exist");
        require(!nodes[nodeUrl].isApproved, "Node is already approved");

        // 找到并从待审核列表中移除
        for (uint i = 0; i < pendingNodeUrls.length; i++) {
            if (
                keccak256(bytes(pendingNodeUrls[i])) ==
                keccak256(bytes(nodeUrl))
            ) {
                // 移动最后一个元素到当前位置
                if (i < pendingNodeUrls.length - 1) {
                    pendingNodeUrls[i] = pendingNodeUrls[
                        pendingNodeUrls.length - 1
                    ];
                }
                pendingNodeUrls.pop();
                break;
            }
        }

        // 添加到已批准列表
        approvedNodeUrls.push(nodeUrl);
        nodes[nodeUrl].isApproved = true;

        emit NodeStatusChanged(nodeUrl, true);
    }

    // 批量批准节点 - 仅管理员可以调用
    function approveNodes(string[] calldata nodeUrls) external onlyNodeManager {
        for (uint i = 0; i < nodeUrls.length; i++) {
            if (nodeUrlExists[nodeUrls[i]] && !nodes[nodeUrls[i]].isApproved) {
                approveNode(nodeUrls[i]);
            }
        }
    }

    // 获取节点信息
    function getNodeInfo(
        string calldata nodeUrl
    )
        external
        view
        returns (
            string memory url,
            address addedBy,
            uint256 addedTime,
            bool isApproved
        )
    {
        require(nodeUrlExists[nodeUrl], "Node URL does not exist");
        NodeInfo storage node = nodes[nodeUrl];
        return (node.url, node.addedBy, node.addedTime, node.isApproved);
    }

    // 删除节点网址 - 仅管理员可以调用
    function removeNodeUrl(string calldata nodeUrl) external onlyNodeManager {
        require(nodeUrlExists[nodeUrl], "Node URL does not exist");

        // 从相应列表中移除
        if (nodes[nodeUrl].isApproved) {
            // 从已批准列表中移除
            for (uint i = 0; i < approvedNodeUrls.length; i++) {
                if (
                    keccak256(bytes(approvedNodeUrls[i])) ==
                    keccak256(bytes(nodeUrl))
                ) {
                    if (i < approvedNodeUrls.length - 1) {
                        approvedNodeUrls[i] = approvedNodeUrls[
                            approvedNodeUrls.length - 1
                        ];
                    }
                    approvedNodeUrls.pop();
                    break;
                }
            }
        } else {
            // 从待审核列表中移除
            for (uint i = 0; i < pendingNodeUrls.length; i++) {
                if (
                    keccak256(bytes(pendingNodeUrls[i])) ==
                    keccak256(bytes(nodeUrl))
                ) {
                    if (i < pendingNodeUrls.length - 1) {
                        pendingNodeUrls[i] = pendingNodeUrls[
                            pendingNodeUrls.length - 1
                        ];
                    }
                    pendingNodeUrls.pop();
                    break;
                }
            }
        }

        // 删除节点信息和记录
        delete nodeUrlExists[nodeUrl];
        delete nodes[nodeUrl];

        emit NodeUrlRemoved(nodeUrl);
    }

    // 批量删除节点 - 仅管理员可以调用
    function removeNodeUrls(
        string[] calldata nodeUrls
    ) external onlyNodeManager {
        for (uint i = 0; i < nodeUrls.length; i++) {
            if (nodeUrlExists[nodeUrls[i]]) {
                // 直接在这里调用外部函数会导致错误，因此内联实现删除逻辑
                string memory nodeUrl = nodeUrls[i];

                // 从相应列表中移除
                if (nodes[nodeUrl].isApproved) {
                    // 从已批准列表中移除
                    for (uint j = 0; j < approvedNodeUrls.length; j++) {
                        if (
                            keccak256(bytes(approvedNodeUrls[j])) ==
                            keccak256(bytes(nodeUrl))
                        ) {
                            if (j < approvedNodeUrls.length - 1) {
                                approvedNodeUrls[j] = approvedNodeUrls[
                                    approvedNodeUrls.length - 1
                                ];
                            }
                            approvedNodeUrls.pop();
                            break;
                        }
                    }
                } else {
                    // 从待审核列表中移除
                    for (uint j = 0; j < pendingNodeUrls.length; j++) {
                        if (
                            keccak256(bytes(pendingNodeUrls[j])) ==
                            keccak256(bytes(nodeUrl))
                        ) {
                            if (j < pendingNodeUrls.length - 1) {
                                pendingNodeUrls[j] = pendingNodeUrls[
                                    pendingNodeUrls.length - 1
                                ];
                            }
                            pendingNodeUrls.pop();
                            break;
                        }
                    }
                }

                // 删除节点信息和记录
                delete nodeUrlExists[nodeUrl];
                delete nodes[nodeUrl];

                emit NodeUrlRemoved(nodeUrl);
            }
        }
    }

    // 获取所有已批准的节点网址
    function getApprovedNodeUrls() external view returns (string[] memory) {
        return approvedNodeUrls;
    }

    // 获取所有待审核的节点网址
    function getPendingNodeUrls() external view returns (string[] memory) {
        return pendingNodeUrls;
    }

    // 获取已批准节点数量
    function getApprovedNodeCount() external view returns (uint) {
        return approvedNodeUrls.length;
    }

    // 获取待审核节点数量
    function getPendingNodeCount() external view returns (uint) {
        return pendingNodeUrls.length;
    }

    // 转让合约所有权
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "New owner cannot be zero address");
        owner = newOwner;
    }

    // 获取合约拥有者
    function getOwner() external view returns (address) {
        return owner;
    }
}
