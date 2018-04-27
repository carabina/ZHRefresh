//  ZHRefreshComponent.swift
//  Refresh
//
//  Created by SummerHF on 27/04/2018.
//
//
//  Copyright (c) 2018 SummerHF(https://github.com/summerhf)
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

import UIKit

/// 刷新控件的状态
enum ZHRefreshState {
    /**普通闲置状态*/
    case idle
    /**松开就可以进行刷新的状态*/
    case pulling
    /**正在刷新中的状态*/
    case refreshing
    /**即将刷新的状态*/
    case willRefresh
    /**所有数据加载完毕, 没有更多的数据了*/
    case nomoreData
}

/// 进入刷新状态的回调
typealias ZHRefreshComponentRefreshingBlock = () -> Void

/// 刷新控件的基类
class ZHRefreshComponent: UIView {
    /// 记录scrollView刚开始的inset
    private var _scrollViewOriginalInset: UIEdgeInsets = UIEdgeInsets.zero
    /// 父控件
    private weak var _scrollView: UIScrollView!
    /// 正在刷新的回调
    var refreshingBlock: ZHRefreshComponentRefreshingBlock?
    /// 回调对象
    var refreshTarget: Any?
    /// 回调方法
    var refreshAction: Selector?
    /// 刷新状态, 一般交给子类内部实现, 默认是普通状态
    var state: ZHRefreshState = .idle
    /// 手势
    var pan: UIPanGestureRecognizer!

    /// 设置回调对象和回调方法
    func setRefreshing(target: Any, action: Selector) {
        self.refreshTarget = target
        self.refreshAction = action
    }

    /// 触发回调(交给子类去处理)
    func executeRefreshingCallBack() {
        DispatchQueue.main.async {
            /// 回调方法
            if let refreshBlock = self.refreshingBlock {
                refreshBlock()
            }
            if let target = self.refreshTarget, let action = self.refreshAction {
                if ZHRefreshRunTime.target(target, canPerform: action) {
                    ZHRefreshRunTime.target(target, perform: action)
                }
            }
        }
    }

    // MARK: - 刷新状态控制

    /// 进入刷新状态
    func beginRefreshing() {
        UIView.animate(withDuration: ZHRefreshKeys.fastAnimateDuration) {
            self.alpha = 1.0
        }
        self.pullingPercent = 1.0
        /// 只要正在刷新, 就完全显示
        if self.window != nil {
            self.state = .refreshing
        } else {
            self.state = .willRefresh
            /// 预防从另一个控制器回到这个控制器的情况, 回来要重新刷一下
            self.setNeedsDisplay()
        }
    }

    /// 结束刷新状态
    func endRefreshing() {
        self.state = .idle
    }

    /// 是否正在刷新
    func isRefreshing() -> Bool {
        return self.state == .refreshing || self.state == .willRefresh
    }

    // MARK: - 交给子类去访问

    /// 记录scrollView刚开始的inset, 只读属性
    var scrollViewOriginalInset: UIEdgeInsets {
        return _scrollViewOriginalInset
    }
    /// 父控件
    var scrollView: UIScrollView {
        return _scrollView
    }

    // MARK: - 其他
    /// 拉拽的百分比(交给子类重写)
    var pullingPercent: CGFloat = 0.0 {
        didSet {
            if self.isRefreshing() { return }
            if self.automaticallyChangeAlpha {
                self.alpha = pullingPercent
            }
        }
    }
    /// 根据拖拽比例自动切换透明度, 默认是false
    var automaticallyChangeAlpha: Bool = false {
        didSet {
            if self.isRefreshing() { return }
            if automaticallyChangeAlpha {
                self.alpha = self.pullingPercent
            } else {
                self.alpha = 1.0
            }
        }
    }

    // MARK: - 初始化

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        /// 准备工作
        self.prepare()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        self.placeSubViews()
    }

    override func willMove(toSuperview newSuperview: UIView?) {
        super.willMove(toSuperview: newSuperview)
        guard let superView = newSuperview else { return }
        /// 如果不是UIScrollView, 不做任何事情
        if !superView.isKind(of: UIScrollView.self) { return }
        /// 新的父控件
        /// 宽度
        self.zh_w = superView.zh_w
        self.zh_x = 0

        /// 记录scrollView
        if let scrollView = superView as? UIScrollView {
           _scrollView = scrollView
            /// 设置永远支持垂直弹簧效果 否则不会出发UIScrollViewDelegate的方法, KVO也会失效
           _scrollView.alwaysBounceVertical = true
            /// 记录UIScrollView最开始的contentInset
           _scrollViewOriginalInset = self.scrollView.contentInset
            /// 添加监听
           self.addObservers()
        }
    }

    override func draw(_ rect: CGRect) {
        super.draw(rect)
        if self.state == .willRefresh {
            /// 预防view还未完全显示就调用了beginRefreshing ?????
            /// FIXME: WHY?
            self.state = .refreshing
        }
    }

    // MARK: - 交给子类们去实现

    /// 初始化
    func prepare() {
        /// 基本属性
        self.autoresizingMask = [.flexibleWidth]
        self.backgroundColor = UIColor.clear
    }

    /// 摆放子控件的frame
    func placeSubViews() {}
    /// 当scrollView的contentOffset发生改变的时候调用
    func scrollViewContentOffsetDid(change: [NSKeyValueChangeKey: Any]) {}
    /// 当scrollView的contentSize发生改变的时候调用
    func scrollViewContentSizeDid(change: [NSKeyValueChangeKey: Any]) {}
    /// 当scrollView的拖拽状态发生改变的时候调用
    func scrollViewPanStateDid(change: [NSKeyValueChangeKey: Any]) {}

    // MARK: - Observers

    /// 添加监听
    func addObservers() {
        let options: NSKeyValueObservingOptions = [NSKeyValueObservingOptions.new, NSKeyValueObservingOptions.old]
        self.scrollView.addObserver(self, forKeyPath: ZHRefreshKeys.contentOffset, options: options, context: nil)
        self.scrollView.addObserver(self, forKeyPath: ZHRefreshKeys.contentSize, options: options, context: nil)
        self.pan = self.scrollView.panGestureRecognizer
        self.pan.addObserver(self, forKeyPath: ZHRefreshKeys.panState, options: options, context: nil)
    }

    /// 移除监听
    func removeObservers() {
        self.superview?.removeObserver(self, forKeyPath: ZHRefreshKeys.contentOffset)
        self.superview?.removeObserver(self, forKeyPath: ZHRefreshKeys.contentSize)
        self.pan.removeObserver(self, forKeyPath: ZHRefreshKeys.panState)
        self.pan = nil
    }

    /// KVO
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        if !self.isUserInteractionEnabled || self.isHidden { return }
        guard let path = keyPath as NSString? else { return }
        /// 未开启手势交互 或者被隐藏 直接返回
        if let chanage = change, path.isEqual(to: ZHRefreshKeys.contentSize) {
            self.scrollViewContentSizeDid(change: chanage)
        } else if let change = change, path.isEqual(to: ZHRefreshKeys.contentOffset) {
            self.scrollViewContentOffsetDid(change: change)
        } else if let change = change, path.isEqual(to: ZHRefreshKeys.panState) {
            self.scrollViewPanStateDid(change: change)
        }
    }
}
