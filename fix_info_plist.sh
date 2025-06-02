#!/bin/bash

# 备份原始项目文件
cp Runner.xcodeproj/project.pbxproj Runner.xcodeproj/project.pbxproj.bak

# 修改项目配置，使用手动创建的Info.plist文件
sed -i '' 's/GENERATE_INFOPLIST_FILE = YES;/GENERATE_INFOPLIST_FILE = NO; INFOPLIST_FILE = Runner\/Info.plist;/g' Runner.xcodeproj/project.pbxproj

echo "项目配置已修改，现在使用手动创建的Info.plist文件。" 