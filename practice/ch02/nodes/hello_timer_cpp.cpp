// 最小 C++ 節點：每 1 秒用 timer 印一行 log
#include <chrono>
#include <memory>

#include "rclcpp/rclcpp.hpp"

using namespace std::chrono_literals;

class HelloTimerCpp : public rclcpp::Node
{
public:
  HelloTimerCpp()
  : Node("hello_timer_cpp")
  {
    timer_ = create_wall_timer(1s, [this]() {
        RCLCPP_INFO(get_logger(), "C++ 節點 tick %d", ++count_);
      });
  }

private:
  rclcpp::TimerBase::SharedPtr timer_;
  int count_ = 0;
};

int main(int argc, char ** argv)
{
  rclcpp::init(argc, argv);
  rclcpp::spin(std::make_shared<HelloTimerCpp>());
  rclcpp::shutdown();
  return 0;
}
