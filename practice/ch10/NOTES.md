# K136 第 10 章 感知（OpenCV／PCL）快速演練筆記

> 快速 demo 模式：只求看懂流程，未經 QA／審查。WSL Ubuntu 24.04 + ROS 2 Jazzy，工作區 `~/k136_ws/ch10`。

## 做了什麼

| 步驟 | 腳本 | 內容 |
| --- | --- | --- |
| 0 | `step0_explore.sh` | 讀書本 `Chapter10` 原始碼、確認 cv_bridge／pcl_ros／image_tools／usb_cam 已安裝 |
| 1 | `step1_build.sh` | 複製 `my_opencv_package`、`pcl_processing`、`usb_cam_launcher` 到 `~/k136_ws/ch10/src`，`colcon build --symlink-install`（書本原檔不動、程式碼未改） |
| 2 | `step2_opencv.sh` | `image_tools cam2image`（burger 模式、10 Hz、remap `image:=/image_raw`）當假相機 → 書上 `image_processing` 節點 → `ros2 topic hz` 量 7 個輸出 topic |
| 3 | `step3_pcl.sh` | `fake_cloud_pub.py` 發布合成點雲到 `/camera/camera/depth/color/points` → 書上 `pcl_processing` → `cloud_checker.py` 數點並用 numpy RANSAC 分割平面 |
| 末 | `cleanup.sh` | 清殘留行程＋`timeout 15 ros2 daemon stop` |

## 驗證結果

**建置**（`logs/step1_build.log`）：`Summary: 3 packages finished [1min 54s]`（pcl_processing 編譯最久）。

**OpenCV**（`logs/step2_opencv.log`）：所有輸出 topic 都跟著輸入維持約 10 Hz。

```text
/image_raw              average rate: 9.991
/gray/image_raw         average rate: 9.986   (mono8, 320x240)
/blur/image_raw         average rate: 9.996
/thresholded/image_raw  average rate: 9.988
/contours/image_raw     average rate: 10.005
/corner/image_raw       average rate: 9.976
/keypoints/image_raw    average rate: 9.993
/prespective/image_raw  width = 0   ← 書上程式沒做透視轉換，發布的是空影像
```

**PCL**（`logs/step3_pcl.log`）：`/filtered_pointcloud` 約 2.1 Hz（跟輸入 2 Hz 一致）。

```text
原始點數=42401 濾波+降採樣後=4897 平面 inlier=4813 雜點(outlier)=84 平面=a=0.009 b=-0.002 c=-1.000 d=0.600
範圍 x[-0.50,0.50] y[-0.50,0.50] z[0.10,0.99]
```

- 合成點雲：z=0.6 m 的水平平面（x,y ∈ [-1,1]、1 cm 間距、2 mm 高斯雜訊，40401 點）＋ 2000 個雜點（[-1.5,1.5]²×[0,2]）。
- PassThrough 把範圍裁到 x,y ∈ [-0.5,0.5]、z ∈ [0.1,1.0]（輸出範圍正好吻合），VoxelGrid 2 cm 降採樣。
- RANSAC 找到的平面 `-z + 0.6 = 0`，就是我們放的 z=0.6 平面。
- 4897 點比理論的 51×51≈2601 多：z=0.6 剛好落在 2 cm 體素的邊界上，加上 2 mm 雜訊，同一欄的點被切到上下兩個體素，點數約翻倍。這是合成資料的副作用，不是程式錯誤。

**清理**（`logs/cleanup.log`）：`乾淨：無殘留`。

## 和書上做法的差異

| 項目 | 書上 | 本演練 |
| --- | --- | --- |
| 影像來源 | 實體 USB webcam，`usb_cam` 讀 `/dev/video2`（1280x720 yuyv） | 沒有 webcam：`cam2image` burger 模式產生 320x240 合成畫面（漢堡圖示在跑），`usb_cam_launcher` 只建置不執行 |
| 點雲來源 | Intel RealSense 深度相機（`realsense2_camera`） | 自寫 `fake_cloud_pub.py`，同一個 topic 名，資料是完美平面＋均勻雜點 |
| 結果檢視 | `rqt_image_view`／RViz 看處理後影像與點雲 | 不開 GUI，改用 `ros2 topic hz`、`topic echo --field`、Python 節點印點數 |
| 分割 | 書上 `pcl_processing` 只有 PassThrough＋VoxelGrid，沒有分割 | 在 `cloud_checker.py` 用 numpy RANSAC 補一個平面分割（不改書上 C++） |
| DDS | 預設 | `RMW_IMPLEMENTATION=rmw_cyclonedds_cpp`、`ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST`（前幾章踩過的坑） |

### 和實體相機的差異（重點）

- **影像內容太乾淨**：burger 畫面是純色背景加簡單圖示，沒有雜訊、光線變化、模糊、鏡頭畸變。閾值 128、ORB、Harris 在真實畫面上結果差很多，這裡只能證明「資料流通、節點不會掛」，不能評估演算法效果。
- **解析度與頻率**：書上 1280x720，本演練 320x240 @10 Hz。真實高解析度下 Harris 那個雙層迴圈（逐像素畫圓）很吃 CPU，頻率可能掉。
- **時間戳**：書上 `image_processing` 發布時用空的 `std_msgs::msg::Header()`，stamp 和 frame_id 都是空的；接 RViz 或做影像同步時會出問題，實體相機情境要改成沿用 `msg->header`。
- **顏色**：`corner/image_raw` 用 `rgb8` 標記但內容其實是 BGR，看圖時紅藍會對調（書上原碼行為）。
- **深度點雲**：RealSense 點雲有空洞、邊緣飛點、NaN、距離越遠越稀疏；合成點雲沒有這些。書上 PassThrough 的 z 範圍 0.1～1.0 m 是依真實相機擺放決定，換場景要重調。
- **硬體相依**：`usb_cam` 需要 `/dev/video*`，WSL 預設看不到 USB 攝影機（要 usbipd 轉接），所以只建置。

## 已知未處理

- 沒有截圖看實際處理後的影像（不開 GUI 的要求）。
- `/prespective/image_raw` 是空影像，書上原碼如此，未修。
