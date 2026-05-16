//telegram @wz662
/** Standard activity result: operation canceled. */
#define ViewControllerResultBack_RESULT_CANCELED     0
/** Standard activity result: operation succeeded. */
#define ViewControllerResultBack_RESULT_OK           -1


/**
 仿照Android的Activity Result机制和原理的delegate，目的是希望下一
 个ViewController中的数据可以通过此delegate，通知给前一个ViewController。

 @author Jack Jiang
 @sine 4.3
 */
@protocol ViewControllerResultBackDelegate <NSObject>

@required//必须实现的代理方法

- (void) onViewControllerResultBack:(int)requestCode resultCode:(int)resultCode withData:(id)data;

@end
