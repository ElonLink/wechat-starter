class PayController < ApplicationController
  before_action :authenticate_user!, except: [:wx_notify]
  skip_before_action :verify_authenticity_token, only: [:wx_notify]

  def wx_pay
    params = {
      body: 'Test Wechat Pay',
      out_trade_no: "trade-#{Time.now.to_i}",
      total_fee: 1,
      spbill_create_ip: request.remote_ip,
      notify_url: Figaro.env.wechat_pay_notify_url,
      trade_type: 'JSAPI',
      openid: current_user.uid
    }

    prepay_result = WxPay::Service.invoke_unifiedorder(params)
    if prepay_result.success?
      render json: pay_params(prepay_result)
    else
      logger.error prepay_result['return_msg']
      render json: prepay_result
    end
  end

  def wx_notify
    result = Hash.from_xml(request.body.read)['xml']
    logger.info result.inspect
    if WxPay::Sign.verify?(result)
      render xml: { return_code: 'SUCCESS', return_msg: 'OK' }.to_xml(root: 'xml', dasherize: false)
    else
      render xml: { return_code: 'FAIL', return_msg: 'Signature Error' }.to_xml(root: 'xml', dasherize: false)
    end
  end

  private

  def pay_params(prepay_result)
    app_id = prepay_result['appid']
    prepay_id = prepay_result['prepay_id']
    nonce_str = prepay_result['nonce_str']
    pay_params = {
      appId: app_id,
      timeStamp: Time.now.to_i.to_s,
      nonceStr: nonce_str,
      package: "prepay_id=#{prepay_id}",
      signType: 'MD5'
    }
    pay_sign = WxPay::Sign.generate(pay_params)
    pay_params.merge(paySign: pay_sign)
  end
end
