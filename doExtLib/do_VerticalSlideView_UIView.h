//
//  do_VerticalSlideView_View.h
//  DoExt_UI
//
//  Created by @userName on @time.
//  Copyright (c) 2015年 DoExt. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "do_VerticalSlideView_IView.h"
#import "do_VerticalSlideView_UIModel.h"
#import "doIUIModuleView.h"

@interface do_VerticalSlideView_UIView : UIScrollView<do_VerticalSlideView_IView, doIUIModuleView>
//可根据具体实现替换UIView
{
	@private
		__weak do_VerticalSlideView_UIModel *_model;
}

@end
