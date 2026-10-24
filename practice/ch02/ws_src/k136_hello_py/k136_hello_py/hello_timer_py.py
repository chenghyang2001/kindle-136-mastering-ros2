"""最小 Python 節點：每 1 秒用 timer 印一行 log"""
import rclpy
from rclpy.executors import ExternalShutdownException
from rclpy.node import Node


class HelloTimerPy(Node):
    def __init__(self):
        super().__init__('hello_timer_py')
        self.count = 0
        self.create_timer(1.0, self.on_timer)

    def on_timer(self):
        self.count += 1
        self.get_logger().info(f'Python 節點 tick {self.count}')


def main(args=None):
    rclpy.init(args=args)
    node = HelloTimerPy()
    try:
        rclpy.spin(node)
    # timeout 送 SIGINT/SIGTERM 時安靜結束，不印 traceback
    except (KeyboardInterrupt, ExternalShutdownException):
        pass
    finally:
        node.destroy_node()
        rclpy.try_shutdown()


if __name__ == '__main__':
    main()
